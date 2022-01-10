using UnityEngine.XR.ARFoundation;

namespace UnityEngine.XR.HoloKit
{
    public class PlaneAreaBehaviour : MonoBehaviour
    {
        private ARPlane m_ARPlane;

        private float m_Area; // In square meters

        private void Start()
        {
            m_ARPlane = GetComponent<ARPlane>();
            m_Area = m_ARPlane.size.x * m_ARPlane.size.y;
            //Debug.Log($"[PlaneAreaBehaviour] start area {m_Area} m2");
            if (PlaneAreaManager.Instance)
            {
                PlaneAreaManager.Instance.OnPlaneAreaChanged(m_ARPlane.classification, 0, m_Area);
            }
            m_ARPlane.boundaryChanged += ArPlane_BoundaryChanged;
        }

        private void OnDestroy()
        {
            if (m_ARPlane)
                m_ARPlane.boundaryChanged -= ArPlane_BoundaryChanged;
        }

        private void ArPlane_BoundaryChanged(ARPlaneBoundaryChangedEventArgs obj)
        {
            float oldArea = m_Area;
            m_Area = m_ARPlane.size.x * m_ARPlane.size.y;
            //Debug.Log($"[PlaneAreaBehaviour] old area {oldArea} and new area {m_Area}");
            if (PlaneAreaManager.Instance)
            {
                PlaneAreaManager.Instance.OnPlaneAreaChanged(m_ARPlane.classification, oldArea, m_Area);
            }
        }
    }
}