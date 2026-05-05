using api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace api.Controllers;

[ApiController]
[Route("[controller]")]
public class EmployeesController : ControllerBase
{
    [Authorize]
    [HttpGet]
    public IActionResult Get()
    {
        var employees = EmployeeService.GetEmployees();
        return Ok(employees);
    }
}
