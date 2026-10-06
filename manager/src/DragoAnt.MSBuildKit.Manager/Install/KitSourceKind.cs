namespace DragoAnt.MSBuildKit.Manager.Install;

/// <summary>Where the kit's packages come from: the configured feeds, or a recorded local folder or checkout.</summary>
internal enum KitSourceKind
{
    Feed,
    Local,
}
