#if UNITY_INPUT_SYSTEM
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.XR;
using UnityEngine.InputSystem.Controls;
using UnityEngine.InputSystem.Layouts;
using UnityEngine.Scripting;

namespace HoloKit.Input
{
    /// <summary>
    /// HoloKit Mixed Reality XR headset.
    /// </summary>
    [Preserve]
    public class HoloKitHME : XRHMD
    {
        [Preserve]
        [InputControl]
        public ButtonControl userPresence { get; private set; }
        [Preserve]
        [InputControl]
        public IntegerControl trackingState { get; private set; }
        [Preserve]
        [InputControl]
        public ButtonControl isTracked { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "HeadPosition" })]
        public Vector3Control devicePosition { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "HeadRotation" })]
        public QuaternionControl deviceRotation { get; private set; }
        [Preserve]
        [InputControl]
        public Vector3Control leftEyePosition { get; private set; }
        [Preserve]
        [InputControl]
        public QuaternionControl leftEyeRotation { get; private set; }
        [Preserve]
        [InputControl]
        public Vector3Control rightEyePosition { get; private set; }
        [Preserve]
        [InputControl]
        public QuaternionControl rightEyeRotation { get; private set; }
        [Preserve]
        [InputControl]
        public Vector3Control centerEyePosition { get; private set; }
        [Preserve]
        [InputControl]
        public QuaternionControl centerEyeRotation { get; private set; }


        protected override void FinishSetup()
        {
            base.FinishSetup();

            userPresence = GetChildControl<ButtonControl>("userPresence");
            trackingState = GetChildControl<IntegerControl>("trackingState");
            isTracked = GetChildControl<ButtonControl>("isTracked");
            devicePosition = GetChildControl<Vector3Control>("devicePosition");
            deviceRotation = GetChildControl<QuaternionControl>("deviceRotation");
            leftEyePosition = GetChildControl<Vector3Control>("leftEyePosition");
            leftEyeRotation = GetChildControl<QuaternionControl>("leftEyeRotation");
            rightEyePosition = GetChildControl<Vector3Control>("rightEyePosition");
            rightEyeRotation = GetChildControl<QuaternionControl>("rightEyeRotation");
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
        public IntegerControl trackingState { get; private set; }
        [Preserve]
        [InputControl]
        public ButtonControl isTracked { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "gripPosition" })]
        public Vector3Control devicePosition { get; private set; }
        [Preserve]
        [InputControl(aliases = new[] { "gripOrientation" })]
        public QuaternionControl deviceRotation { get; private set; }
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
