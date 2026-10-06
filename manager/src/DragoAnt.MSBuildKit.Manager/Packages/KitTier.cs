namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>Who publishes a kit package; a later tier overrides an earlier one.</summary>
internal enum KitTier
{
    Core,
    Company,
    Team,
}
