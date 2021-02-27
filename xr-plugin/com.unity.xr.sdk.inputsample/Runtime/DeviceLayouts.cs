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
    [InputControlLayout(displayName = "HoloKit Hand")]
    public class HoloKitHand : XRController
    {
        [Preserve]
        [InputControl]
        public IntegerControl trackingState { get; private set; }
        [Preserve]
        [InputControl]
        public ButtonControl isTracked { get; private set; }
        [Preserve]
        [InputControl]
        public IntegerControl handedness { get; private set; }
        [Preserve]
        [InputControl]
        public ButtonControl airTap { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control wrist { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control thumbStart { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control thumb1 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control thumb2 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control thumbEnd { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control indexStart { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control index1 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control index2 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control indexEnd { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control midStart { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control mid1 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control mid2 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control midEnd { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control ringStart { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control ring1 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control ring2 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control ringEnd { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control pinkyStart { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control pinky1 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control pinky2 { get; private set; }
        [Preserve]
        [InputControl]
        public Bone​Control pinkyEnd { get; private set; }

        protected override void FinishSetup()
        {
            base.FinishSetup();

            trackingState = GetChildControl<IntegerControl>("trackingState");
            isTracked = GetChildControl<ButtonControl>("isTracked");
            handedness = GetChildControl<IntegerControl>("handedness");
            airTap = GetChildControl<ButtonControl>("airTap");

            wrist = GetChildControl<Bone​Control>("wrist");

            thumbStart = GetChildControl<Bone​Control>("thumbStart");
            thumb1 = GetChildControl<Bone​Control>("thumb1");
            thumb2 = GetChildControl<Bone​Control>("thumb2");
            thumbEnd = GetChildControl<Bone​Control>("thumbEnd");

            indexStart = GetChildControl<BoneControl>("indexStart");
            index1 = GetChildControl<BoneControl>("index1");
            index2 = GetChildControl<BoneControl>("index2");
            indexEnd = GetChildControl<BoneControl>("indexEnd");

            midStart = GetChildControl<Bone​Control>("midStart");
            mid1 = GetChildControl<Bone​Control>("mid1");
            mid2 = GetChildControl<Bone​Control>("mid2");
            midEnd = GetChildControl<Bone​Control>("midEnd");

            ringStart = GetChildControl<Bone​Control>("ringStart");
            ring1 = GetChildControl<Bone​Control>("ring1");
            ring2 = GetChildControl<Bone​Control>("ring2");
            ringEnd = GetChildControl<Bone​Control>("ringEnd");

            pinkyStart = GetChildControl<Bone​Control>("pinkyStart");
            pinky1 = GetChildControl<Bone​Control>("pinky1");
            pinky2 = GetChildControl<Bone​Control>("pinky2");
            pinkyEnd = GetChildControl<Bone​Control>("pinkyEnd");
        }
    }
}
#endif //#if UNITY_INPUT_SYSTEM
