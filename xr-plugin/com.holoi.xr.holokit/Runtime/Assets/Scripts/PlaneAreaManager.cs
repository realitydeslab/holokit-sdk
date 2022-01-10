using System.Collections.Generic;
using UnityEngine.Events;
using UnityEngine.XR.ARSubsystems;

namespace UnityEngine.XR.HoloKit
{
    public class PlaneAreaManager : MonoBehaviour
    {
        private static PlaneAreaManager _instance;

        public static PlaneAreaManager Instance { get { return _instance; } }

        private Dictionary<PlaneClassification, float> m_PlaneClassification2Area;

        public Dictionary<PlaneClassification, float> PlaneClassification2Area => m_PlaneClassification2Area;

        public float TotalArea
        {
            get
            {
                float totalArea = 0;
                foreach (var area in m_PlaneClassification2Area.Values)
                {
                    totalArea += area;
                }
                return totalArea;
            }
        }

        public event UnityAction PlaneAreaChangedEvent;

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(this.gameObject);
            }
            else
            {
                _instance = this;
            }

            m_PlaneClassification2Area = new();
            m_PlaneClassification2Area.Add(PlaneClassification.None, 0);
            m_PlaneClassification2Area.Add(PlaneClassification.Wall, 0);
            m_PlaneClassification2Area.Add(PlaneClassification.Floor, 0);
            m_PlaneClassification2Area.Add(PlaneClassification.Ceiling, 0);
            m_PlaneClassification2Area.Add(PlaneClassification.Table, 0);
            m_PlaneClassification2Area.Add(PlaneClassification.Seat, 0);
            m_PlaneClassification2Area.Add(PlaneClassification.Door, 0);
            m_PlaneClassification2Area.Add(PlaneClassification.Window, 0);
        }

        public void OnPlaneAreaChanged(PlaneClassification classification, float oldArea, float newArea)
        {
            m_PlaneClassification2Area[classification] += -oldArea + newArea;
            PlaneAreaChangedEvent?.Invoke();
        }
    }
}