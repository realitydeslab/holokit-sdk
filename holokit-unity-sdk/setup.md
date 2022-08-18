# Setup

This section will illustrate how to install HoloKit SDK and setup Unity before you can build a HoloKit project.

### Install HoloKit SDK

Copy the HoloKit SDK folder and put it into the Unity project's **Packages** folder.![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=YzQzNmUxMDViOWViMjkyN2YxM2FlMGE0NmVlN2NiYThfNFlwVGVGczBEUmVlUWNrVm85cTZnSkJJdExwOFZGSVVfVG9rZW46Ym94Y25sZHU3ZlFoNkhadFQ2NExsZHV4d21nXzE2NjA4NTc0MTM6MTY2MDg2MTAxM19WNA)

All dependency packages will be installed automatically after HoloKit SDK is installed, which are ARFoundation, ARKit, XR Plugin Management and URP (we highly recommend you use URP for all HoloKit projects).

## Setup ARKit

Open Edit -> Project Settings -> XR Plug-in Management -> iOS, make sure "Apple ARKit" is selected. Please also make sure "Initialize XR on Startup" is selected.![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=ODZlNmIwMjZmMjdhNmViM2ExOWI3NTAwY2Y2MDNiMTNfZ3A3azhQZFdEVFZCU3lYU0dtMFpYd0lzOHZpenFweWtfVG9rZW46Ym94Y25hZnVqc0dvMVh1TElNMktqWk4yejhkXzE2NjA4NTc0MTM6MTY2MDg2MTAxM19WNA)

## Add Camera Usage Description

Open Edit -> Project Settings -> Player -> Other Settings, fill in "Camera Usage Description"![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=YzViMThjZTgxY2NjN2FmYjExYmI0NDEwNTg0OWRiN2JfMDM4UjFYMTkyczR0RmpLY1RDWkFJajk3Z3hlcEwxUkFfVG9rZW46Ym94Y25MZXUzNkF6bmVPdlZ2OFpuQnVsSk5mXzE2NjA4NTc0MTM6MTY2MDg2MTAxM19WNA)

## Change the render pipeline to URP

(This step is optional, you can build a HoloKit project with Unity default render pipeline. But we highly recommend you to use URP since VFXs have a very good effect on HoloKit and they are only supported under URP)

Create a new URP Asset by

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=Njc1YWRkNTdiZjQ0ZDU2YjM2NzdjYWIxODg0MzE5MTZfMWh0eVNBZ25OMzBUd2tXZ0JnNUpITFltekRTUHZCZ3RfVG9rZW46Ym94Y25Kb1Q2eU01UXM2SnlYblU1TUdWdTg5XzE2NjA4NTc0MTM6MTY2MDg2MTAxM19WNA)

After creating the URP asset, select its corresponding renderer![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=YzFjMTFmMWM5YWI2OWNhM2IzZTcxNWY2MTY3Yjk2ZmZfRHpmeTU1aWZMZ3ZOd0VOdjZZdkRHUlUySWw5YWl4STRfVG9rZW46Ym94Y25TMXNabmlNYUVEcVhhQkpNMFhmUERmXzE2NjA4NTc0MTM6MTY2MDg2MTAxM19WNA)

Add "AR Background Render Feature"

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=MDBhMjkwYWU4NmZmYmM4Mjk1YzYwYWI4YTdlMzc0OWZfSFlqa0lSM24ybnlKYmhNQlp6bHVYUkI2Sk1DMHVJUGtfVG9rZW46Ym94Y242Tm81R1lvVzBrMlBtcGRFMEhOWmliXzE2NjA4NTc0MTM6MTY2MDg2MTAxM19WNA)

Finally, open Edit -> Project Settings -> Graphics, and drag the newly created URP asset onto "Scriptable Render Pipeline Settings"

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=Y2Y5MWY5MWExMmJmYTI0YzYxMzBiNDRmZjZlNjAzYjFfU2xoRXRMZ0VPOTJtUGhTMmtFdXlucDdJZ25RMk9rc1VfVG9rZW46Ym94Y24xM0xOcExwU0k0M1FvM1Z5N0VsSnpiXzE2NjA4NTc0MTM6MTY2MDg2MTAxM19WNA)\
