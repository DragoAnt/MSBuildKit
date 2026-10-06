using DragoAnt.MSBuildKit.Manager.Install;

namespace DragoAnt.MSBuildKit.Manager.Tests.Install;

public sealed class KitLayoutTests
{
    private static readonly string Root = Path.Combine(Path.GetTempPath(), "repo");

    [Fact]
    public void Default_PutsTheKitInDotMskit()
    {
        var layout = new KitLayout(Root);

        layout.KitDirName.Should().Be(".mskit");
        layout.KitPath.Should().Be(Path.Combine(Root, ".mskit"));
        layout.KitJsonPath.Should().Be(Path.Combine(Root, ".mskit", "kit.json"));
        layout.MsbuildPath.Should().Be(Path.Combine(Root, ".mskit", "msbuild"));
        layout.InitPropsPath.Should().Be(Path.Combine(Root, ".mskit", "msbuild", "init.props"));
        layout.InitTargetsPath.Should().Be(Path.Combine(Root, ".mskit", "msbuild", "init.targets"));
        layout.LocalPath.Should().Be(Path.Combine(Root, ".mskit", ".local"));
        layout.ManagerPath.Should().Be(Path.Combine(Root, ".mskit", ".manager"));
        layout.PackagesProjectPath.Should().Be(Path.Combine(Root, ".mskit", ".manager", "packages.csproj"));
        layout.LockFilePath.Should().Be(Path.Combine(Root, ".mskit", ".manager", "packages.lock.json"));
        layout.ManifestPath.Should().Be(Path.Combine(Root, ".mskit", ".manager", "manifest.json"));
        layout.PackageContentPath("DragoAnt.MSBuildKit.Testing")
            .Should().Be(Path.Combine(Root, ".mskit", "msbuild", "DragoAnt.MSBuildKit.Testing"));
    }

    [Theory]
    [InlineData(".toolkit")]
    [InlineData("build/kit")]
    public void CustomKitDir_IsUsedForEveryPath(string kitDir)
    {
        var layout = new KitLayout(Root, kitDir);

        layout.KitDirName.Should().Be(kitDir);
        layout.ManifestPath.Should().Be(Path.Combine(Root, kitDir, ".manager", "manifest.json"));
    }

    [Theory]
    [InlineData("")]
    [InlineData("  ")]
    [InlineData("..")]
    [InlineData("a/../b")]
    [InlineData("/abs")]
    [InlineData("C:/abs")]
    public void InvalidKitDir_Throws(string kitDir)
    {
        var act = () => new KitLayout(Root, kitDir);

        act.Should().Throw<ArgumentException>().WithMessage("*kit*");
    }

    [Theory]
    [InlineData("")]
    [InlineData("a/b")]
    [InlineData("a\\b")]
    [InlineData("..")]
    public void PackageContentPath_RejectsAnIdThatIsNotOneFolderName(string packageId)
    {
        var act = () => new KitLayout(Root).PackageContentPath(packageId);

        act.Should().Throw<ArgumentException>();
    }
}
