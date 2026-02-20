namespace Volingo.Api.Services;

/// <summary>
/// Thrown when the AI determines the input is not a real English word.
/// </summary>
public class WordNotFoundException : Exception
{
    public string Word { get; }

    public WordNotFoundException(string word)
        : base($"'{word}' is not a recognized English word.")
    {
        Word = word;
    }
}
