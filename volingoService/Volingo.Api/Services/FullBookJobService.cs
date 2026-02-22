using System.Collections.Concurrent;
using System.Text;
using System.Text.Json;
using System.Threading.Channels;
using Microsoft.Azure.Cosmos;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Background service that processes full-book question generation jobs.
/// Uses Channel&lt;T&gt; as an in-memory queue and BackgroundService for execution.
/// Survives browser sleep — progress is tracked server-side.
/// </summary>
public sealed class FullBookJobService : BackgroundService
{
    private readonly Channel<string> _channel = Channel.CreateUnbounded<string>();
    private readonly ConcurrentDictionary<string, FullBookJobState> _jobs = new();
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<FullBookJobService> _logger;

    public FullBookJobService(IServiceProvider serviceProvider, ILogger<FullBookJobService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    // ── Public API for endpoints ──

    /// <summary>Start a new full-book generation job. Returns jobId.</summary>
    public string StartJob(string docId, string textbook, string displayName,
        string textbookCode, List<UnitInfo> units, List<GlossaryEntry> glossary, string level)
    {
        var jobId = Guid.NewGuid().ToString("N")[..12];
        var steps = new List<FullBookStep>();

        foreach (var unit in units)
        {
            foreach (var qtype in QuestionTypes.All)
            {
                steps.Add(new FullBookStep
                {
                    UnitNumber = unit.UnitNumber,
                    UnitTitle = unit.UnitTitle ?? "",
                    QuestionType = qtype
                });
            }
        }

        var state = new FullBookJobState
        {
            JobId = jobId,
            DocId = docId,
            Textbook = textbook,
            TextbookCode = textbookCode,
            DisplayName = displayName,
            Level = level,
            Units = units,
            Glossary = glossary,
            Steps = steps,
            TotalSteps = steps.Count,
            Status = JobStatus.Queued,
            CreatedAt = DateTime.UtcNow,
            Cts = new CancellationTokenSource()
        };

        _jobs[jobId] = state;
        _channel.Writer.TryWrite(jobId);
        _logger.LogInformation("Job {JobId} queued: {DisplayName}, {StepCount} steps",
            jobId, displayName, steps.Count);
        return jobId;
    }

    /// <summary>Get current job state (for polling).</summary>
    public FullBookJobState? GetJob(string jobId) =>
        _jobs.TryGetValue(jobId, out var state) ? state : null;

    /// <summary>Cancel a running job.</summary>
    public bool CancelJob(string jobId)
    {
        if (!_jobs.TryGetValue(jobId, out var state)) return false;
        if (state.Status is not (JobStatus.Running or JobStatus.Queued)) return false;
        state.Cts.Cancel();
        return true;
    }

    /// <summary>Resume a cancelled job from where it left off.</summary>
    public bool ResumeJob(string jobId)
    {
        if (!_jobs.TryGetValue(jobId, out var state)) return false;
        if (state.Status is not JobStatus.Cancelled) return false;
        state.Cts = new CancellationTokenSource();
        state.Status = JobStatus.Queued;
        _channel.Writer.TryWrite(jobId);
        _logger.LogInformation("Job {JobId} resumed from step {Step}/{Total}",
            jobId, state.CompletedSteps, state.TotalSteps);
        return true;
    }

    /// <summary>List recent jobs (last 20).</summary>
    public List<FullBookJobState> ListJobs() =>
        _jobs.Values.OrderByDescending(j => j.CreatedAt).Take(20).ToList();

    // ── Background execution ──

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var jobId in _channel.Reader.ReadAllAsync(stoppingToken))
        {
            if (!_jobs.TryGetValue(jobId, out var job)) continue;

            try
            {
                await ProcessJobAsync(job, stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Job {JobId} fatal error", jobId);
                job.Status = JobStatus.Failed;
                job.AddLog("💥 致命错误: " + ex.Message, "#ff3b30");
            }
        }
    }

    private async Task ProcessJobAsync(FullBookJobState job, CancellationToken appStopping)
    {
        job.Status = JobStatus.Running;
        job.StartedAt ??= DateTime.UtcNow;

        using var linked = CancellationTokenSource.CreateLinkedTokenSource(appStopping, job.Cts.Token);
        var ct = linked.Token;

        // Create a DI scope for scoped services
        using var scope = _serviceProvider.CreateScope();
        var generator = scope.ServiceProvider.GetRequiredService<IQuestionGeneratorService>();
        var cosmos = scope.ServiceProvider.GetRequiredService<CosmosClient>();
        var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        var dbName = config["CosmosDb:DatabaseName"] ?? "volingo";
        var container = cosmos.GetContainer(dbName, "questions");

        job.AddLog($"🚀 开始整书出题：{job.DisplayName}");
        job.AddLog($"共 {job.Units.Count} 个单元 × {QuestionTypes.All.Length} 种题型 = {job.TotalSteps} 步");

        var currentUnit = -1;

        for (var i = 0; i < job.Steps.Count; i++)
        {
            if (ct.IsCancellationRequested) break;

            var step = job.Steps[i];
            if (step.Status == StepStatus.Done) continue; // skip completed (for resume)

            // Unit header
            if (step.UnitNumber != currentUnit)
            {
                currentUnit = step.UnitNumber;
                var unitLabel = step.UnitNumber == 0 ? "Starter" : $"Unit {step.UnitNumber}";
                job.AddLog($"──── {unitLabel}: {step.UnitTitle} ────");
            }

            step.Status = StepStatus.Running;
            job.CurrentStep = $"Unit {step.UnitNumber} — {step.QuestionType}";

            var unit = job.Units.First(u => u.UnitNumber == step.UnitNumber);
            var request = new GenerateQuestionsRequest(
                TextbookCode: job.TextbookCode,
                DisplayName: job.DisplayName,
                Level: job.Level,
                UnitNumber: step.UnitNumber,
                Unit: unit,
                Glossary: job.Glossary,
                QuestionType: step.QuestionType
            );

            try
            {
                // Step 1: Generate
                var questions = await generator.GenerateQuestionsAsync(request);
                job.TotalGenerated += questions.Count;

                if (questions.Count == 0)
                {
                    step.Status = StepStatus.Done;
                    step.Message = "生成 0 道";
                    job.CompletedSteps++;
                    job.ErrorCount++;
                    job.AddLog($"  ⚠️ {step.QuestionType}: 生成 0 道题，跳过", "#ff9500");
                    continue;
                }

                // Step 2: Commit to Cosmos
                int committed = 0;
                foreach (var q in questions)
                {
                    if (!q.ContainsKey("id"))
                        q["id"] = Guid.NewGuid().ToString();

                    if (!q.TryGetValue("textbookCode", out var tbObj) || tbObj is null)
                        continue;

                    OpenAIQuestionGeneratorService.ShuffleOptions(q);

                    var json = JsonSerializer.Serialize(q);
                    using var stream = new MemoryStream(Encoding.UTF8.GetBytes(json));
                    await container.UpsertItemStreamAsync(stream, new PartitionKey(tbObj.ToString()!));
                    committed++;
                }

                job.TotalCommitted += committed;
                step.Status = StepStatus.Done;
                step.QuestionsGenerated = questions.Count;
                step.QuestionsCommitted = committed;
                step.Message = $"{questions.Count} 道生成，{committed} 道入库";
                job.CompletedSteps++;
                job.AddLog($"  ✅ {step.QuestionType}: {questions.Count} 道已生成，{committed} 道已入库", "#34c759");
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                step.Status = StepStatus.Failed;
                step.Message = ex.Message;
                job.CompletedSteps++;
                job.ErrorCount++;
                job.AddLog($"  ❌ {step.QuestionType}: {ex.Message}", "#ff3b30");
                _logger.LogWarning(ex, "Job {JobId} step {Step} failed", job.JobId, step.QuestionType);
            }
        }

        // Final status
        if (ct.IsCancellationRequested && !appStopping.IsCancellationRequested)
        {
            job.Status = JobStatus.Cancelled;
            job.AddLog($"⏹ 已停止。已入库 {job.TotalCommitted} 道题目。", "#ff9500");
        }
        else if (job.ErrorCount > 0 && job.TotalCommitted > 0)
        {
            job.Status = JobStatus.Completed;
            job.AddLog($"🎉 完成！入库 {job.TotalCommitted} 道，{job.ErrorCount} 个错误。", "#34c759");
        }
        else if (job.TotalCommitted == 0)
        {
            job.Status = JobStatus.Failed;
            job.AddLog($"💥 全部失败，0 道入库。", "#ff3b30");
        }
        else
        {
            job.Status = JobStatus.Completed;
            job.AddLog($"🎉 整书出题完成！生成 {job.TotalGenerated} 道，入库 {job.TotalCommitted} 道。", "#34c759");
        }

        job.FinishedAt = DateTime.UtcNow;
    }
}

// ── Models ──

public enum JobStatus { Queued, Running, Completed, Cancelled, Failed }
public enum StepStatus { Pending, Running, Done, Failed }

public sealed class FullBookStep
{
    public int UnitNumber { get; set; }
    public string UnitTitle { get; set; } = "";
    public string QuestionType { get; set; } = "";
    public StepStatus Status { get; set; } = StepStatus.Pending;
    public string? Message { get; set; }
    public int QuestionsGenerated { get; set; }
    public int QuestionsCommitted { get; set; }
}

public sealed class FullBookJobState
{
    public string JobId { get; set; } = "";
    public string DocId { get; set; } = "";
    public string Textbook { get; set; } = "";
    public string TextbookCode { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string Level { get; set; } = "";
    public List<UnitInfo> Units { get; set; } = [];
    public List<GlossaryEntry> Glossary { get; set; } = [];
    public List<FullBookStep> Steps { get; set; } = [];

    public JobStatus Status { get; set; } = JobStatus.Queued;
    public string? CurrentStep { get; set; }
    public int TotalSteps { get; set; }
    public int CompletedSteps { get; set; }
    public int TotalGenerated { get; set; }
    public int TotalCommitted { get; set; }
    public int ErrorCount { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? FinishedAt { get; set; }

    // Log entries (capped at 500)
    private readonly List<LogEntry> _logs = [];
    private int _logVersion;

    public void AddLog(string message, string? color = null)
    {
        lock (_logs)
        {
            _logs.Add(new LogEntry(DateTime.UtcNow, message, color));
            if (_logs.Count > 500) _logs.RemoveAt(0);
            _logVersion++;
        }
    }

    /// <summary>Get log entries after a given index (for incremental polling).</summary>
    public (List<LogEntry> Entries, int Version) GetLogsSince(int sinceVersion)
    {
        lock (_logs)
        {
            if (sinceVersion >= _logVersion)
                return ([], _logVersion);

            // Calculate how many new entries
            var totalAdded = _logVersion;
            var available = _logs.Count;
            var skip = Math.Max(0, available - (totalAdded - sinceVersion));
            return (_logs.Skip(skip).ToList(), _logVersion);
        }
    }

    // Not serialized
    [System.Text.Json.Serialization.JsonIgnore]
    public CancellationTokenSource Cts { get; set; } = new();
}

public record LogEntry(DateTime Timestamp, string Message, string? Color);
