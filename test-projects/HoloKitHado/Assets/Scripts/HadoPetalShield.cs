using System.Collections;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Messaging;
using MLAPI.Connection;
using MLAPI.NetworkVariable;

public class HadoPetalShield : NetworkBehaviour
{
    private Transform m_ARCamera;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_HitPetalShieldAudioClip;

    private float m_PetalShieldYOffset = -0.6f;

    private float m_PetalShieldZOffset = 0.4f;

    private int m_CurrentHealth;

    private int k_MaxHeath = 4;

    private float m_LastHitTime = 0f;

    private const float k_RecoveryTime = 3f;

    /// <summary>
    /// If the petal shield is still alive?
    /// </summary>
    private bool m_IsPresent = true;

    public static NetworkVariableBool ShouldDestroyAllInstances = new NetworkVariableBool(new NetworkVariableSettings
    {
        WritePermission = NetworkVariablePermission.ServerOnly,
        ReadPermission = NetworkVariablePermission.Everyone
    }, false);

    private void Start()
    {
        m_AudioSource = GetComponent<AudioSource>();
        if (IsOwner) {
            m_ARCamera = Camera.main.transform;
        }
        if (IsServer)
        {
            m_CurrentHealth = k_MaxHeath;
        }
    }

    private void Update()
    {
        if (IsOwner)
        {
            Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
            Vector3 frontVector = Vector3.ProjectOnPlane(m_ARCamera.forward, new Vector3(0f, 1f, 0f)).normalized;
            transform.position = centerEyePosition + frontVector * m_PetalShieldZOffset + new Vector3(0f, m_PetalShieldYOffset, 0f);

            Vector3 cameraEuler = m_ARCamera.rotation.eulerAngles;
            transform.rotation = Quaternion.Euler(new Vector3(0f, cameraEuler.y, 0f));
        }

        // Shield's health recovers if not gets hit.
        //if (m_IsPresent && Time.time - m_LastHitTime > k_RecoveryTime)
        //{
        //    if (m_CurrentHealth != k_MaxHeath)
        //    {
        //        m_CurrentHealth++;
        //        // TODO: Modify the VFX parameter

        //        OnPetalShieldRecoveredServerRpc();
        //    }
        //}

        if (IsServer)
        {
            if (ShouldDestroyAllInstances.Value)
            {
                StartCoroutine(WaitForDestroy(2.0f));
            }
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        // Each petal shield is handled by its owner.
        if (!IsServer)
        {
            return;
        }

        if (other.tag.Equals("Bullet") || other.tag.Equals("DragonBullet"))
        {
            m_LastHitTime = Time.time;
            m_CurrentHealth--;

            // We are not the owner of this network object, we cannot call a server rpc here.
            // But we can call a client rpc.
            OnPetalShieldHitClientRpc();

            if (m_CurrentHealth == 0)
            {
                m_IsPresent = false;

                StartCoroutine(WaitForDestroy(0.3f));

                
                if (SceneManager.GetActiveScene().name.Equals("HadoTestScene"))
                {
                    // We only destroy other players' shield in PvP
                    ShouldDestroyAllInstances.Value = true;
                    // The owner of this shield loses.
                    var playerScript = GetPlayerScript(NetworkManager.Singleton.LocalClientId);
                    if (playerScript != null)
                    {
                        playerScript.RoundOverServerRpc(OwnerClientId);
                    }
                }
                else if (SceneManager.GetActiveScene().name.Equals("PPvE"))
                {
                    var playerScript = GetPlayerScript(OwnerClientId);
                    if (playerScript != null)
                    {
                        playerScript.ReviveClientRpc();
                    }
                }
            }
        }
    }

    [ClientRpc]
    private void OnPetalShieldHitClientRpc()
    {
        transform.GetChild(0).GetComponent<PetalSelfControl>().OnExplode();
        m_AudioSource.clip = m_HitPetalShieldAudioClip;
        m_AudioSource.Play();
    }

    IEnumerator WaitForDestroy(float time)
    {
        yield return new WaitForSeconds(time);
        Destroy(gameObject);
    }

    private HadoPlayer GetPlayerScript(ulong clientId)
    {
        if (!NetworkManager.Singleton.ConnectedClients.TryGetValue(clientId, out NetworkClient networkClient))
        {
            return null;
        }

        if (!networkClient.PlayerObject.TryGetComponent<HadoPlayer>(out HadoPlayer script))
        {
            return null;
        }
        return script;
    }
}
