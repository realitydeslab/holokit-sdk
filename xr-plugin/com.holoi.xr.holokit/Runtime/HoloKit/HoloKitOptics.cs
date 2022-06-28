using UnityEngine;

namespace HoloKit
{
    public static class HoloKitOptics
    {
        public static HoloKitCameraData GetHoloKitCameraData(HoloKitModel holokitModel, PhoneModel phoneModel, float ipd, float farClipPlane)
        {
            // 1. Calculate projection matrices
            // Reference: http://www.songho.ca/opengl/gl_projectionmatrix.html
            float viewportWidthInMeters = holokitModel.ViewportInner + holokitModel.ViewportOuter;
            float viewportHeightInMeters = holokitModel.ViewportTop + holokitModel.ViewportBottom;
            float nearClipPlane = holokitModel.LensToEye;
            float viewportsFullWidthInMeters = holokitModel.OpticalAxisDistance + 2f * holokitModel.ViewportOuter;
            float gap = viewportsFullWidthInMeters - viewportWidthInMeters * 2f;

            Matrix4x4 leftProjectionMatrix = Matrix4x4.zero;
            leftProjectionMatrix[0, 0] = 2f * nearClipPlane / viewportWidthInMeters;
            leftProjectionMatrix[1, 1] = 2f * nearClipPlane / viewportHeightInMeters;
            leftProjectionMatrix[0, 2] = (ipd - viewportWidthInMeters - gap) / viewportWidthInMeters;
            leftProjectionMatrix[2, 2] = (-farClipPlane - nearClipPlane) / (farClipPlane - nearClipPlane);
            leftProjectionMatrix[2, 3] = -2f * farClipPlane * nearClipPlane / (farClipPlane - nearClipPlane);
            leftProjectionMatrix[3, 2] = -1f;

            Matrix4x4 rightProjectionMatrix = leftProjectionMatrix;
            rightProjectionMatrix[0, 2] = -leftProjectionMatrix[0, 2];

            // 2. Calculate viewport rects
            float centerX = 0.5f + phoneModel.CenterLineOffset / phoneModel.ScreenWidth;
            float centerY = (holokitModel.AxisToBottom - phoneModel.ScreenBottom) / phoneModel.ScreenHeight;
            float fullWidth = viewportsFullWidthInMeters / phoneModel.ScreenWidth;
            float width = viewportWidthInMeters / phoneModel.ScreenWidth;
            float height = viewportHeightInMeters / phoneModel.ScreenHeight;

            float xMinLeft = centerX - fullWidth / 2f;
            float xMaxLeft = xMinLeft + width;
            float xMinRight = centerX + fullWidth / 2f - width;
            float xMaxRight = xMinRight + width;
            float yMin = centerY - height / 2f;
            float yMax = centerY + height / 2f;

            Rect leftViewportRect = Rect.MinMaxRect(xMinLeft, yMin, xMaxLeft, yMax);
            Rect rightViewportRect = Rect.MinMaxRect(xMinRight, yMin, xMaxRight, yMax);

            // 3. Calculate offsets
            Vector3 cameraToCenterEyeOffset = phoneModel.CameraOffset + holokitModel.MrOffset;
            Vector3 centerEyeToLeftEyeOffset = new(-ipd / 2f, 0f, 0f);
            Vector3 centerEyeToRightEyeOffset = new(ipd / 2f, 0f, 0f);

            float alignmentMarkerOffset = holokitModel.HorizontalAlignmentMarkerOffset / phoneModel.ScreenWidth * Screen.width;

            return new HoloKitCameraData
            {
                LeftViewportRect = leftViewportRect,
                RightViewportRect = rightViewportRect,
                NearClipPlane = nearClipPlane,
                FarClipPlane = farClipPlane,
                LeftProjectionMatrix = leftProjectionMatrix,
                RightProjectionMatrix = rightProjectionMatrix,
                CameraToCenterEyeOffset = cameraToCenterEyeOffset,
                CenterEyeToLeftEyeOffset = centerEyeToLeftEyeOffset,
                CenterEyeToRightEyeOffset = centerEyeToRightEyeOffset,
                AlignmentMarkerOffset = alignmentMarkerOffset
            };
        }
    }
}
