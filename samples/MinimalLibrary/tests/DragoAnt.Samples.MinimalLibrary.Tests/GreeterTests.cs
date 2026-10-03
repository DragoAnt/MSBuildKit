namespace DragoAnt.Samples.MinimalLibrary.Tests;

public sealed class GreeterTests
{
    [Theory]
    [InlineData("Ada", "Hello, Ada!")]
    [InlineData("  Ada ", "Hello, Ada!")]
    [InlineData(null, "Hello, world!")]
    [InlineData("", "Hello, world!")]
    public void Greet_WhenNameGiven_ReturnsGreeting(string? name, string expected) =>
        Greeter.Greet(name).Should().Be(expected);

    [Fact]
    public void Length_IsVisibleToTests_ThroughInternalsVisibleTo() =>
        Greeter.Length("abc").Should().Be(3);
}
