using System;
using System.Runtime.InteropServices;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HoloKit
{
    public static class HoloKitOpticsAPI
    {
        [DllImport("__Internal")]
        private static extern IntPtr HoloKitSDK_GetHoloKitCameraData(int holokitType, float ipd, float farClipPlane);

        public static HoloKitCameraData GetHoloKitCameraData(HoloKitType holokitType, float ipd, float farClipPlane)
        {
            IntPtr data = HoloKitSDK_GetHoloKitCameraData((int)holokitType, ipd, farClipPlane);
            float[] result = new float[55];
            Marshal.Copy(data, result, 0, 55);
            Rect leftViewportRect = Rect.MinMaxRect(result[0], result[1], result[2], result[3]);
            Rect rightViewportRect = Rect.MinMaxRect(result[4], result[5], result[6], result[7]);
            Matrix4x4 leftProjectionMatrix = Matrix4x4.zero;
            for (int i = 0; i < 4; i++)
            {
                for (int j = 0; j < 4; j++)
                {
                    leftProjectionMatrix[i, j] = result[10 + 4 * i + j];
                }
            }
            Matrix4x4 rightProjectionMatrix = Matrix4x4.zero;
            for (int i = 0; i < 4; i++)
            {
                for (int j = 0; j < 4; j++)
                {
                    rightProjectionMatrix[i, j] = result[26 + 4 * i + j];
                }
            }
            return new HoloKitCameraData
            {
                LeftViewportRect = leftViewportRect,
                RightViewportRect = rightViewportRect,
                NearClipPlane = result[8],
                FarClipPlane = result[9],
                LeftProjectionMatrix = leftProjectionMatrix,
                RightProjectionMatrix = rightProjectionMatrix,
                CameraToCenterEyeOffset = new Vector3(result[42], result[43], result[44]),
                CameraToScreenCenterOffset = new Vector3(result[45], result[46], result[47]),
                CenterEyeToLeftEyeOffset = new Vector3(result[48], result[49], result[50]),
                CenterEyeToRightEyeOffset = new Vector3(result[51], result[52], result[53]),
                AlignmentMarkerOffset = result[54]
            };
        }
    }
}