namespace UnityEngine.XR.HoloKit
{
    public enum iOSThermalState
    {
        ThermalStateNominal = 0,
        ThermalStateFair = 1,
        ThermalStateSerious = 2,
        ThermalStateCritical = 3
    }

    public enum ARKitCameraTrackingState
    {
        NotAvailable = 0,
        LimitedWithReasonNone = 1,
        LimitedWithReasonInitializing = 2,
        LimitedWithReasonExcessiveMotion = 3,
        LimitedWithReasonInsufficientFeatures = 4,
        LimitedWithReasonRelocalizing = 5,
        Normal = 6
    }
}
