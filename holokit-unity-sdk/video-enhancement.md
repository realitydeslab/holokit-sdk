# Video Enhancement

If you are using an iOS 16 iPhone, you can use video enhancement to get a better background video quality.There are 3 video enhancement options, which are

```
public enum VideoEnhancementMode
{
    None = 0,      // Default HD
    HighRes = 1,   // 4K
    HighResWithHDR // 4K with HDR
}
```

To enable video enhancement, you will need to set `VideoEnhancementMode` in `HoloKitCamera` script, as shown below

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=YTAzYjcwZDJmOWQxN2IwZmVjNzU5ZDgzNzNhOTNkOTBfMFhET3lJMFlIOWhlQm5LcndUZjRiU1pKZVF5ZDdCZTlfVG9rZW46Ym94Y25UT1dqVVJJMHhjY1RSYm82Y1R3OGtmXzE2NjA4NTc3NDM6MTY2MDg2MTM0M19WNA)

There are several things you need to know before you can safely use video enhancement:

* When you enable 4K, the FPS will be dropped to 30.
* Video enhancement is very energy consuming, so we highly recommend you not use video enhancement and hand tracking at the same time.
* You cannot enable HDR without enabling 4K , and that is why we don't provide a single HDR mode.
* Only iPhone 11 and up can enable 4K mode.
