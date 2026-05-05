namespace bff.Services;

public class ApiClient
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;

    public ApiClient(HttpClient httpClient, IConfiguration config)
    {
        _httpClient = httpClient;
        _config = config;
    }

    public async Task<HttpResponseMessage> GetEmployeesAsync(string accessToken)
    {
        var apiUrl = _config["Api:BaseUrl"];
        var url = $"{apiUrl}/Employees";

        var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);

        return await _httpClient.SendAsync(request);
    }
}
