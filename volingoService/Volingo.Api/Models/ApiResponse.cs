namespace Volingo.Api.Models;

public record ApiResponse<T>(int Code, string Message, T? Data)
{
    public static ApiResponse<T> Success(T data) => new(200, "success", data);
    public static ApiResponse<T> Error(int code, string message) => new(code, message, default);
}

public record ApiResponse(int Code, string Message, object? Data)
{
    public static ApiResponse Success(object? data = null) => new(200, "success", data);
    public static ApiResponse Error(int code, string message) => new(code, message, null);
}
