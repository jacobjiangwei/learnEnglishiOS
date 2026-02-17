using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Reads questions from the question bank.
/// </summary>
public interface IQuestionService
{
    Task<(List<object> Questions, int Remaining)> GetQuestionsAsync(
        string textbookCode, string questionType, int count, IReadOnlySet<string> completedIds);

    Task<TodayPackageResponse> GetTodayPackageAsync(string textbookCode);
}
