using UnityEngine;

namespace HoloKit
{
    // TODO: Get HoloKitType from NFC?
    public enum HoloKitType
    {
        HoloKitX = 0
    }

    public enum PhoneType
    {
        iPhoneXS = 0,
        iPhoneXSMax = 1,
        iPhone11Pro = 2,
        iPhone11ProMax = 3,
        iPhone12 = 4,
        iPhone12Pro = 5,
        iPhone12ProMax = 6,
        iPhone13 = 7,
        iPhone13Pro = 8,
        iPhone13ProMax = 9,
        iPad = 10, // all iPads are the same to us
        Unknown = 11
    }

    public struct HoloKitModel
    {
        /// <summary>
        /// Distance beetween eyes
        /// </summary>
        public float OpticalAxisDistance;

        /// <summary>
        /// 3D offset from the center of bottomline of the holokit phone display to the center of two eyes.
        /// </summary>
        public Vector3 MrOffset;

        /// <summary>
        /// Eye view area width
        /// </summary>
        public float ViewportInner;

        /// <summary>
        /// Eye view area height
        /// </summary>
        public float ViewportOuter;

        /// <summary>
        /// Eye view area spillter width
        /// </summary>
        public float ViewportTop;

        /// <summary>
        /// Eye view area spillter width
        /// </summary>
        public float ViewportBottom;

        /// <summary>
        /// Fresnel lens focal length
        /// </summary>
        public float FocalLength;

        /// <summary>
        /// Screen To Fresnel distance
        /// </summary>
        public float ScreenToLens;

        /// <summary>
        /// Fresnel To eye distance
        /// </summary>
        public float LensToEye;

        /// <summary>
        /// Bottom of the holder to bottom of the view
        /// </summary>
        public float AxisToBottom;

        /// <summary>
        /// The distance between the center of the HME and the marker
        /// </summary>
        public float HorizontalAlignmentMarkerOffset;
    }

    public struct PhoneModel
    {
        /// <summary>
        /// The long screen edge of the phone
        /// </summary>
        public float ScreenWidth;

        /// <summary>
        /// The short screen edge of the phone
        /// </summary>
        public float ScreenHeight;

        /// <summary>
        /// The distance from the bottom of display area to the touching surface of the holokit phone holder
        /// </summary>
        public float ScreenBottom;

        /// <summary>
        /// The distance from the center of the display to the rendering center
        /// </summary>
        public float CenterLineOffset;

        /// <summary>
        /// The 3D offset vector from center of the camera to the center of the display area's bottomline
        /// </summary>
        public Vector3 CameraOffset;
    }
    public static class HoloKitProfile
    {
        public static HoloKitModel GetHoloKitModel(HoloKitType holokitType)
        {
            switch(holokitType)
            {
                case HoloKitType.HoloKitX:
                    return new HoloKitModel
                    {
                        OpticalAxisDistance = 0.064f,
                        MrOffset = new Vector3(0f, -0.02894f, -0.07055f),
                        ViewportInner = 0.0292f,
                        ViewportOuter = 0.0292f,
                        ViewportTop = 0.02386f,
                        ViewportBottom = 0.02386f,
                        FocalLength = 0.065f,
                        ScreenToLens = 0.02715f + 0.03136f + 0.002f,
                        LensToEye = 0.02497f + 0.03898f,
                        AxisToBottom = 0.02990f,
                        HorizontalAlignmentMarkerOffset = 0.05075f,
                    };
                default:
                    return new HoloKitModel();
            }
        }

        public static PhoneModel GetPhoneModel()
        {
            PhoneType phoneType = GetPhoneType();
            switch (phoneType)
            {
                case PhoneType.iPhoneXS:
                    return new PhoneModel
                    {
                        ScreenWidth = 0.135097f,
                        ScreenHeight = 0.062391f,
                        ScreenBottom = 0.00391f,
                        CenterLineOffset = 0f,
                        CameraOffset = new Vector3(0.05986f, -0.055215f, -0.0091f)
                    };
                case PhoneType.iPhoneXSMax:
                    return new PhoneModel
                    {
                        ScreenWidth = 0.14971f,
                        ScreenHeight = 0.06961f,
                        ScreenBottom = 0.00391f,
                        CenterLineOffset = -0.006f,
                        CameraOffset = new Vector3(0.06694f, -0.09405f, -0.00591f)
                    };
                case PhoneType.iPhone11Pro:
                    return new PhoneModel
                    {
                        ScreenWidth = 0.13495f,
                        ScreenHeight = 0.06233f,
                        ScreenBottom = 0.00452f,
                        CenterLineOffset = 0f,
                        CameraOffset = new Vector3(0.05996f, -0.02364f - 0.03494f, -0.00591f)
                    };
                case PhoneType.iPhone11ProMax:
                    return new PhoneModel
                    {
                        ScreenWidth = 0.14891f,
                        ScreenHeight = 0.06881f,
                        ScreenBottom = 0.00452f,
                        CenterLineOffset = 0f,
                        CameraOffset = new Vector3(0.066945f, -0.061695f, -0.0091f)
                    };
                case PhoneType.iPhone12:
                case PhoneType.iPhone13:
                    return new PhoneModel
                    {
                        ScreenWidth = 0.13977f,
                        ScreenHeight = 0.06458f,
                        ScreenBottom = 0.00347f,
                        CenterLineOffset = 0f,
                        CameraOffset = new Vector3(0.05996f, -0.02364f - 0.03494f, -0.00591f)
                    };
                case PhoneType.iPhone12Pro:
                case PhoneType.iPhone13Pro:
                    return new PhoneModel
                    {
                        ScreenWidth = 0.13977f,
                        ScreenHeight = 0.06458f,
                        ScreenBottom = 0.00347f,
                        CenterLineOffset = 0f,
                        CameraOffset = new Vector3(0.05996f, -0.02364f - 0.03494f, -0.00591f)
                    };
                case PhoneType.iPhone12ProMax:
                case PhoneType.iPhone13ProMax:
                    return new PhoneModel
                    {
                        ScreenWidth = 0.15390f,
                        ScreenHeight = 0.07113f,
                        ScreenBottom = 0.00347f,
                        CenterLineOffset = 0f,
                        CameraOffset = new Vector3(0.066945f, -0.061695f, -0.0091f)
                    };
                case PhoneType.iPad:
                case PhoneType.Unknown:
                default:
                    return new PhoneModel
                    {
                        ScreenWidth = 0.15390f,
                        ScreenHeight = 0.07113f,
                        ScreenBottom = 0.00347f,
                        CenterLineOffset = 0f,
                        CameraOffset = new Vector3(0.066945f, -0.061695f, -0.0091f)
                    };
            }
        }

        public static PhoneType GetPhoneType()
        {
            return SystemInfo.deviceModel switch
            {
                // iPhones
                "iPhone11,2" => PhoneType.iPhoneXS,
                "iPhone11,4" => PhoneType.iPhoneXSMax,
                "iPhone11,6" => PhoneType.iPhoneXSMax,
                "iPhone12,3" => PhoneType.iPhone11Pro,
                "iPhone12,5" => PhoneType.iPhone11ProMax,
                "iPhone13,2" => PhoneType.iPhone12,
                "iPhone13,3" => PhoneType.iPhone12Pro,
                "iPhone13,4" => PhoneType.iPhone12ProMax,
                "iPhone14,5" => PhoneType.iPhone13,
                "iPhone14,2" => PhoneType.iPhone13Pro,
                "iPhone14,3" => PhoneType.iPhone13ProMax,
                // iPads
                // TODO: Add more iPads
                "iPad13,8" => PhoneType.iPad,
                "iPad13,9" => PhoneType.iPad,
                "iPad13,10" => PhoneType.iPad,
                "iPad13,11" => PhoneType.iPad,
                // Not supported devices
                _ => PhoneType.Unknown
            };
        }
    }
}