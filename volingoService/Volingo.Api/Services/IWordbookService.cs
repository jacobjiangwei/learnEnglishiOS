using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Manages per-device wordbook (add / delete / list).
/// </summary>
public interface IWordbookService
{
    Task<WordbookEntry> AddWordAsync(string deviceId, WordbookAddRequest request);
    Task<bool> DeleteWordAsync(string deviceId, string wordId);
    Task<WordbookListResponse> GetWordbookAsync(string deviceId);
}
