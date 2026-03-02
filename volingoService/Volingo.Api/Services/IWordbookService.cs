using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Manages per-user wordbook (add / delete / list).
/// </summary>
public interface IWordbookService
{
    Task<WordbookEntry> AddWordAsync(string userId, WordbookAddRequest request);
    Task<bool> DeleteWordAsync(string userId, string wordId);
    Task<WordbookListResponse> GetWordbookAsync(string userId);
}
