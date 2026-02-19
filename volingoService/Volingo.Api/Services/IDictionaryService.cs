using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Dictionary lookup: Cosmos DB cache → AI fallback → upsert to Cosmos.
/// </summary>
public interface IDictionaryService
{
    /// <summary>
    /// Look up a word. Returns cached entry from Cosmos DB, or generates one via AI if not found.
    /// </summary>
    Task<DictionaryResponse> LookupAsync(string word);
}
