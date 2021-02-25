using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using UnityEngine.XR;

public class GetNodeStates : MonoBehaviour {

    Dictionary<ulong, GameObject> m_NodeStates;

    void Awake()
    {
        m_NodeStates = new Dictionary<ulong, GameObject>();
    }

    void Update()
    {
        NodesUpdate();
    }

    void NodesUpdate()
    {
        List<XRNodeState> nodeStates = new List<XRNodeState>();
        InputTracking.GetNodeStates(nodeStates);

        GameObject tempGameObject;
        Vector3 tempVector3 = Vector3.zero;
        Quaternion tempQuaternion = Quaternion.identity;
        foreach (XRNodeState nodeState in nodeStates)
        {
            if (m_NodeStates.ContainsKey(nodeState.uniqueID))
            {
                m_NodeStates.TryGetValue(nodeState.uniqueID, out tempGameObject);
            }
            else
            {
                AddNewNodeVisual(nodeState);
            }

            m_NodeStates.TryGetValue(nodeState.uniqueID, out tempGameObject);
            if (nodeState.TryGetPosition(out tempVector3))
            {
                tempGameObject.transform.localPosition = tempVector3;
            }
            else
            {
                tempGameObject.transform.localPosition = Vector3.zero;
            }

            if (nodeState.TryGetRotation(out tempQuaternion))
            {
                tempGameObject.transform.localRotation = tempQuaternion;
            }
            else
            {
                tempGameObject.transform.localRotation = Quaternion.identity;            
            }
        }

        bool foundMatch = false;
        List<ulong> toRemove = new List<ulong>();
        foreach (KeyValuePair<ulong, GameObject> nodeState in m_NodeStates)
        {
            foundMatch = false;
            foreach (XRNodeState ns in nodeStates)
            {
                if (ns.uniqueID == nodeState.Key)
                {
                    foundMatch = true;
                    break;
                }
            }
            if (!foundMatch)
            {
                m_NodeStates.TryGetValue(nodeState.Key, out tempGameObject);
                Destroy(tempGameObject);
                toRemove.Add(nodeState.Key);
            }
        }

        for(int i = 0; i < toRemove.Count; i++)
        {
            m_NodeStates.Remove(toRemove[i]);
        }
    }

    void AddNewNodeVisual (XRNodeState nodeState)
    {
        GameObject newNodeVisual = GameObject.CreatePrimitive(PrimitiveType.Cube);
        newNodeVisual.transform.SetParent(gameObject.transform);
        newNodeVisual.transform.localScale = new Vector3(0.1f, 0.1f, 0.1f);
        GameObject TextGameObject = new GameObject();
        TextGameObject.transform.SetParent(newNodeVisual.transform);

        TextMesh newTextMesh = TextGameObject.AddComponent<TextMesh>();
        newTextMesh.text = nodeState.nodeType.ToString();
        newTextMesh.color = Color.black;
        newTextMesh.characterSize = 0.01f;
        newTextMesh.fontSize = 50;

        m_NodeStates.Add(nodeState.uniqueID, newNodeVisual);
    }
}
