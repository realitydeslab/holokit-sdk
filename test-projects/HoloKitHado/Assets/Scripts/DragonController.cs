using System.Collections;
using UnityEngine;
using UnityEngine.InputSystem;
using MLAPI;
using MLAPI.Messaging;

public class DragonController : NetworkBehaviour
{
    private Vector3 m_position;
    private Vector3 m_rotation;
    [SerializeField]
    private float m_rotateSpeed = 1f;
    [SerializeField]
    private float m_walkSpeed = 1f;

    private int m_CurrentHeath;
    private const int k_MaxHeath = 20;

    Animator m_animator;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_AttackAudioClip;

    [SerializeField] private AudioClip m_OnHitAudioClip;

    [SerializeField] private AudioClip m_WingsAudioClip;

    [SerializeField] private AudioClip m_DeathAudioClip;

    [SerializeField] private NetworkObject m_DragonBulletPrefab;

    [SerializeField] private Transform m_DragonMouse;

    private float m_DragonBulletSpeed = 160f;

    private void Start()
    {
        m_AudioSource = GetComponent<AudioSource>();
        m_animator = GetComponent<Animator>();
        if (IsServer)
        {
            m_CurrentHeath = k_MaxHeath;
        }   
    }

    private void Update()
    {
        if (!IsOwner) { return; }

        Movement();
    }

    void Movement()
    {
        m_rotation = transform.rotation.eulerAngles;
        m_position = transform.position;

        var gamepad = Gamepad.current;
        if (gamepad == null)
            return; // No gamepad connected.

        Vector2 move1 = gamepad.leftStick.ReadValue();
        Vector2 move2 = gamepad.rightStick.ReadValue();

        // 'Move' code here
        transform.rotation *= Quaternion.Euler(new Vector3(0, move2.x * Time.deltaTime * m_rotateSpeed, 0));

        transform.position += transform.forward * move1.y * Time.deltaTime * m_walkSpeed + transform.right * move1.x * Time.deltaTime * m_walkSpeed;

        if (gamepad.rightStick.IsPressed())
        {

        }

        if (gamepad.yButton.wasReleasedThisFrame)
        {
            ScaleDragonClientRpc(1.1f);
        }

        if (gamepad.xButton.wasReleasedThisFrame)
        {
            ScaleDragonClientRpc(0.9f);
        }

        if (gamepad.aButton.wasReleasedThisFrame)
        {
            AttackClientRpc();
            var bulletInstance = Instantiate(m_DragonBulletPrefab, m_DragonMouse.position, Quaternion.identity);
            bulletInstance.Spawn();

            bulletInstance.GetComponent<Rigidbody>().AddForce(transform.forward * m_DragonBulletSpeed);
        }

        if (gamepad.bButton.isPressed)
        {

        }

        if (gamepad.leftTrigger.IsPressed())
        {
            transform.position -= new Vector3(0, 0.01f, 0);
        }

        if (gamepad.rightTrigger.IsPressed())
        {
            transform.position += new Vector3(0, 0.01f, 0);
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if (!IsServer) { return; }

        if (other.tag.Equals("Bullet"))
        {
            m_CurrentHeath--;
            if (m_CurrentHeath == 0)
            {
                StartCoroutine(WaitAndDestroy(1.667f));
                OnDeathClientRpc();
            }
            else
            {
                OnHitClientRpc();
            }
        }
    }

    [ClientRpc]
    private void OnHitClientRpc()
    {
        m_animator.SetTrigger("Fly Take Damage");
        m_AudioSource.clip = m_OnHitAudioClip;
        m_AudioSource.Play();
    }

    [ClientRpc]
    private void OnDeathClientRpc()
    {
        m_animator.SetTrigger("Fly Die");
        m_AudioSource.clip = m_DeathAudioClip;
        m_AudioSource.Play();
    }

    [ClientRpc]
    private void AttackClientRpc()
    {
        Debug.Log("AttackClientRpc");
        m_animator.SetTrigger("Fly Projectile Attack");
        m_AudioSource.clip = m_AttackAudioClip;
        m_AudioSource.Play();
    }

    IEnumerator WaitAndDestroy(float time)
    {
        yield return new WaitForSeconds(time);
        Destroy(gameObject);
    }

    [ClientRpc]
    private void ScaleDragonClientRpc(float value)
    {
        transform.localScale *= value;
    }
}
