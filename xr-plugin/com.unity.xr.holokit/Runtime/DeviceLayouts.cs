#if UNITY_INPUT_SYSTEM
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.XR;
using UnityEngine.InputSystem.Controls;
using UnityEngine.InputSystem.Layouts;
using UnityEngine.Scripting;

namespace UnityEngine.XR.HoloKit.Input
{
    /// <summary>
    /// HoloKit Mixed Reality XR headset.
    /// </summary>
    [Preserve]
    [InputControlLayout(displayName = "HoloKit HMD")]
    public class HoloKitHMD : XRHMD
    {
        [Preserve]
        [InputControl]
        public new IntegerControl trackingState { get; private set; }
        [Preserve]
        [InputControl]
        public new ButtonControl isTracked { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "HeadPosition" })]
        public new Vector3Control devicePosition { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "HeadRotation" })]
        public new QuaternionControl deviceRotation { get; private set; }
        [Preserve]
        public new Vector3Control centerEyePosition { get; private set; }
        [Preserve]
        [InputControl]
        public new QuaternionControl centerEyeRotation { get; private set; }


        protected override void FinishSetup()
        {
            base.FinishSetup();

            trackingState = GetChildControl<IntegerControl>("trackingState");
            isTracked = GetChildControl<ButtonControl>("isTracked");
            centerEyePosition = GetChildControl<Vector3Control>("centerEyePosition");
            centerEyeRotation = GetChildControl<QuaternionControl>("centerEyeRotation");
        }
    }

    [Preserve]
    [InputControlLayout(displayName = "HoloKit Hand", commonUsages = new[] { "LeftHand", "RightHand" })]
    public class HoloKitHand : XRController
    {
        [Preserve]
        [InputControl]
        public new IntegerControl trackingState { get; private set; }
        [Preserve]
        [InputControl]
        public new ButtonControl isTracked { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "gripPosition" })]
        public new Vector3Control devicePosition { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "gripOrientation" })]
        public new QuaternionControl  deviceRotation { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "gripVelocity" })]
        public Vector3Control deviceVelocity { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "triggerbutton" })]
        public ButtonControl airTap { get; private set; }
        [Preserve]
        [InputControl]
        public AxisControl sourceLossRisk { get; private set; }
        [Preserve]
        [InputControl]
        public Vector3Control sourceLossMitigationDirection { get; private set; }

        protected override void FinishSetup()
        {
            base.FinishSetup();

            airTap = GetChildControl<ButtonControl>("airTap");
            trackingState = GetChildControl<IntegerControl>("trackingState");
            isTracked = GetChildControl<ButtonControl>("isTracked");
            devicePosition = GetChildControl<Vector3Control>("devicePosition");
            deviceRotation = GetChildControl<QuaternionControl>("deviceRotation");
            deviceVelocity = GetChildControl<Vector3Control>("deviceVelocity");
            sourceLossRisk = GetChildControl<AxisControl>("sourceLossRisk");
            sourceLossMitigationDirection = GetChildControl<Vector3Control>("sourceLossMitigationDirection");
        }
    }
}
#endif //#if UNITY_INPUT_SYSTEM
