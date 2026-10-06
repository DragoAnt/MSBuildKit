using DragoAnt.MSBuildKit.Manager.Infrastructure;

namespace DragoAnt.MSBuildKit.Manager.Tests.Infrastructure;

public sealed class PathUtilsTests
{
    private static readonly string Root = Path.Combine(Path.GetTempPath(), "mskit-root");

    [Theory]
    [InlineData("a/b.txt", true)]
    [InlineData(".", true)]
    [InlineData("../mskit-root-sibling/x.txt", false)]
    [InlineData("../x.txt", false)]
    [InlineData("a/../../x.txt", false)]
    public void IsPathUnderRoot_ComparesTheResolvedPath(string relative, bool expected) =>
        PathUtils.IsPathUnderRoot(Path.Combine(Root, relative), Root).Should().Be(expected);

    [Fact]
    public void IsPathUnderRoot_WhenOnAnotherDrive_IsFalse()
    {
        Assert.SkipUnless(OperatingSystem.IsWindows(), "drive letters exist only on Windows");
        var drive = char.ToUpperInvariant(Path.GetPathRoot(Root)![0]) == 'Z' ? 'Y' : 'Z';

        PathUtils.IsPathUnderRoot($@"{drive}:\elsewhere\x.txt", Root).Should().BeFalse();
    }

    [Theory]
    [InlineData(@"\msbuild\a.props", "msbuild/a.props")]
    [InlineData("/msbuild/a.props", "msbuild/a.props")]
    [InlineData("msbuild/a.props", "msbuild/a.props")]
    public void NormalizePath_UsesForwardSlashesWithoutLeadingSlash(string input, string expected) =>
        PathUtils.NormalizePath(input).Should().Be(expected);
}
