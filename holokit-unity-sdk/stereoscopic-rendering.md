# Stereoscopic rendering



This sample is the minimalist version of a HoloKit project, which only contains 3 cubes with stereoscopic rendering enabled.

1. Create a new Unity scene and delete everything in it
2. Drag "HoloKit Utility" prefab into the scene

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=YjBmZjc2ZGNkNDM5NmUxNTQwM2M4MWFiZTkyNzdhMGRfQklvekFCYUJCc0FVVExlT05Bd2dUYVpLOUV1WlpTOGFfVG9rZW46Ym94Y25PdGpIYm5YQnp6d2syZ3pNRGZjbFJkXzE2NjA4NTc1NjU6MTY2MDg2MTE2NV9WNA)

1. Add "XR Origin" and "AR Session" to the scene

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=MTUzY2U2NWFmOGM0NTM0OWIxZjdjZjcxOTc3NzllODNfVm9XeU1ubzRBaVV5M0hXOWh5Q2NiRGUxTnFaQVlVSVVfVG9rZW46Ym94Y24xVFBCWUtydmZBRWtwSUFtekFkN1ZiXzE2NjA4NTc1NjU6MTY2MDg2MTE2NV9WNA)

1. Delete the default "Main Camera" under "XR Origin" and replace it with "HoloKit Camera" prefab

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=NzM5NWZhZDEzMzA2YjhiOWFlOWVhMmJmYjU0NjBkYTdfV0RQQWU2T0dQaFZnWktOSzFsMFpoSm5tTjNhSlNPVGZfVG9rZW46Ym94Y245UHR2QmNoUWVTT1N3dG9EYkQ3S0tmXzE2NjA4NTc1NjU6MTY2MDg2MTE2NV9WNA)

1. Update the "Camera GameObject" of "XROrigin" with the "HoloKit Camera"

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=MTRkNjhkNDQ0OTYzN2IwZDM5OTJiODliZjQ0MzNmZTFfdWJySEVrS1hYa2xlR3VjZ255V3JzMTRqN2pCYXFLMkxfVG9rZW46Ym94Y243aGdOcGJtUFlxSk4zcGo4VG04dWJjXzE2NjA4NTc1NjU6MTY2MDg2MTE2NV9WNA)

1. Add a button to switch render mode

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=OGJlMDQwZmQ3YmVhNDdjMDQyMzQ0ODk0MmYxMGRlZDZfTFBQb01raFdrdTRWNUNycnRzSUdacTIzMnI5SWlVM2tfVG9rZW46Ym94Y25qV2N1SmgwdmZzUHhmVFJWVVlqSm5lXzE2NjA4NTc1NjU6MTY2MDg2MTE2NV9WNA)You also need to write a script to control the render mode and UI . Here is an example

```csharp
using UnityEngine;
using TMPro;

namespace HoloKit.Samples.StereoscopicRendering
{
    public class UIController : MonoBehaviour
    {
        [SerializeField] private TMP_Text _renderModeText;

        private void Awake()
        {
            HoloKitCamera.OnHoloKitRenderModeChanged += OnHoloKitRenderModeChanged;
        }

        private void OnDestroy()
        {
            HoloKitCamera.OnHoloKitRenderModeChanged -= OnHoloKitRenderModeChanged;
        }

        public void ToggleRenderMode()
        {
            if (HoloKitCamera.Instance.RenderMode == HoloKitRenderMode.Stereo)
            {
                HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Mono;
            }
            else
            {
                HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Stereo;
            }
        }

        private void OnHoloKitRenderModeChanged(HoloKitRenderMode renderMode)
        {
            if (renderMode == HoloKitRenderMode.Stereo)
            {
                _renderModeText.text = "Mono";
            }
            else
            {
                _renderModeText.text = "Stereo";
            }
        }
    }
}
```

`HoloKitCamera` is a singleton class which controls the rendering mode. You can get the current rendering mode by

```csharp
HoloKitCamera.Instance.RenderMode
```

The variable `HoloKitCamera.Instance.RenderMode` is an enum which contains only two values

```csharp
public enum HoloKitRenderMode
{
    Mono = 0,    // Normal screen AR
    Stereo = 1   // Stereoscopic rendering
}
```

In order to activate stereoscopic rendering, you do

```csharp
HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Stereo;
```

After setting the `HoloKitCamera.Instance.RenderMode` to `HoloKitRenderMode.Stereo`, the NFC session is triggered and you need to put the iPhone onto the HoloKit to authenticate the NFC chip. If the NFC session succeeds, `HoloKitCamera.Instance.RenderMode` will be changed to `HoloKitRenderMode.Stereo`. If the NFC session fails, nothing will happen.If you want to change the render mode back to `HoloKitRenderMode.Mono`, just do

```csharp
HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Mono;
```

This process does not need any authentication and the render mode will be changed instantly.When the value of `HoloKitCamera.Instance.RenderMode` is changed successfully, the callback `HoloKitCamera.OnHoloKitRenderModeChanged` will be triggered to indicate that change.
