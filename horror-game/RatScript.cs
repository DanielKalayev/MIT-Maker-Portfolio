using System.Collections;
using System.Collections.Generic;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.AI;

enum RatMovementState { idle, walking, running }
public enum RatState { stalking, chasing, fleeting, venting }

public class RatScript : MonoBehaviour
{
    public static RatScript instance;

    [Header("AI")]
    [SerializeField] private LayerMask groundLayer;
    [SerializeField] private Transform ventSpot;
    private NavMeshAgent agent;
    private Transform player;
    private Rigidbody rb;

    [Header("Animation")]
    private Animator animator;

    [Header("Audio")]
    [SerializeField] private AudioSource stalkingVL;
    [SerializeField] private AudioSource chasingVL;
    [SerializeField] private AudioSource fleetingVL;
    [SerializeField] private AudioSource jumpVL;
    [SerializeField] private AudioSource hurtVL;

    [Header("States")]
    [SerializeField] private RatMovementState moveState;
    public RatState ratState { get; private set; }

    float stalkTime = 0f;
    float chasingTime = 0f;
    float attackCd = 0f;

    bool isAttacking = false;
    bool canKill = false;
    bool isVenting = false;

    private Vent currentVent = null;

    [Header("Settings")]
    [SerializeField] private float maxStalkTime;
    [SerializeField] private float maxChaseTime;
    [Space]
    [SerializeField] private float minVentTime;
    [SerializeField] private float maxVentTime;
    [Space]
    [SerializeField] private float attackCooldown;

    [Space]

    [SerializeField] private float jumpPower;

    private Coroutine attackRoutine;

    [Header("Stun")]
    [SerializeField] private float stunTime = 2f;

    private bool isStunned = false;

    private int lives = 2;

    private void Awake()
    {
        instance = this;
        agent = GetComponent<NavMeshAgent>();
        animator = GetComponent<Animator>();
        rb = GetComponent<Rigidbody>();
    }

    void Start()
    {
        moveState = RatMovementState.idle;
        player = Player.instance.transform;
        agent.isStopped = false;

        attackCd = 0;

        RestartState(RatState.venting);
        StartCoroutine(BehaviorLoop());
    }

    void Update()
    {
        UpdRatState();
        UpdMoveState();
    }

    private IEnumerator BehaviorLoop()
    {
        yield return null;

        while (true)
        {
            if (stalkTime > maxStalkTime && ratState == RatState.stalking)
            {
                RestartState(RatState.chasing);
            }
            else if (chasingTime > maxChaseTime && ratState == RatState.chasing && !isAttacking)
            {
                RestartState(RatState.fleeting);
            }
            else if (ratState == RatState.fleeting)
            {
                Vent vent;
                Transform targetPos;

                Vent.GetNearestReachable(transform, agent, out vent, out targetPos);

                agent.SetDestination(targetPos.position);

                yield return new WaitUntil(() => Distance() <= 6);

                vent.ToggleVent(true);

                yield return new WaitUntil(() => agent.remainingDistance < 0.5f);

                vent.ToggleVent(false);

                yield return new WaitUntil(() => !agent.pathPending && agent.remainingDistance <= agent.stoppingDistance);

                yield return new WaitForSeconds(1.5f);

                currentVent = vent;
                RestartState(RatState.venting);
            }
            else if (ratState == RatState.venting)
            {
                if (isVenting)
                {
                    agent.enabled = false;
                    transform.position = ventSpot.position;

                    yield return new WaitForSeconds(Random.Range(minVentTime, maxVentTime));

                    Vent targetVent = DecideNewVent();

                    //no vent
                    if (targetVent == null)
                    {
                        yield return new WaitForSeconds(5f);
                        yield return null;
                        continue;
                    }

                    isVenting = false;
                    transform.position = targetVent.ventSpot.position;

                    yield return new WaitForSeconds(1f);

                    //Pop out
                    targetVent.ToggleVent(true);

                    agent.enabled = true;
                    agent.Warp(transform.position);

                    RestartState(RatState.stalking);

                    yield return new WaitForSeconds(1.75f);
                    targetVent.ToggleVent(false);
                }
            }

            yield return null;
        }
    }

    private float Distance()
    {
        return (agent.destination - transform.position).magnitude;
    }

    private void RestartState(RatState state)
    {
        switch (state)
        {
            case RatState.stalking:
                stalkTime = 0f;
                lives = 2;
                break;

            case RatState.chasing:
                chasingTime = 0f;
                attackCd = -2.5f;
                chasingVL.Play();
                break;

            case RatState.fleeting:
                fleetingVL.Play();
                break;

            case RatState.venting:
                isVenting = true;
                break;
        }
        ratState = state;
    }

    private Vent DecideNewVent()
    {
        foreach (KeycardDoor door in KeycardDoor.doors)
        {
            if (!door.PlayerIsInRoom() || door.doorOpen) continue;

            Vent best = null;
            float closestDist = Mathf.Infinity;

            foreach (Vent v in Vent.VentList)
            {
                if (v == null) continue;

                if (door.PosIsInRoom(v.ventSpot.position))
                {
                    float dist = Vector3.Distance(player.position, v.ventSpot.position);
                    if (dist < closestDist)
                    {
                        closestDist = dist;
                        best = v;
                    }
                }
            }

            if (best != null) return best;
        }

        Vent nearest = null;
        float nearestDist = Mathf.Infinity;

        foreach (Vent v in Vent.VentList)
        {
            if (v == null) continue;

            bool isInsideRoom = false;
            foreach (KeycardDoor door in KeycardDoor.doors)
            {
                if (door.PosIsInRoom(v.ventSpot.position))
                {
                    isInsideRoom = true;
                    break;
                }
            }

            if (isInsideRoom) continue;

            float dist = Vector3.Distance(player.position, v.ventSpot.position);
            if (dist < nearestDist)
            {
                nearestDist = dist;
                nearest = v;
            }
        }

        if (nearest == null)
        {
            foreach (Vent v in Vent.VentList)
            {
                if (v == null) continue;

                float dist = Vector3.Distance(player.position, v.ventSpot.position);
                if (dist < nearestDist)
                {
                    nearestDist = dist;
                    nearest = v;
                }
            }
        }

        return nearest;
    }

    private void VentUpdate()
    {
        if (isVenting)
        {
            agent.enabled = false;
            transform.position = ventSpot.position;
        }
    }

    private void UpdRatState()
    {
        stalkingVL.enabled = ratState == RatState.stalking;

        if (isStunned || isAttacking) return;

        switch (ratState)
        {
            case RatState.stalking:
                moveState = (Distance() > 2) ? RatMovementState.walking : RatMovementState.idle;

                if (Player.instance.usingMenu)
                {
                    agent.SetDestination(player.position + (PlayerCamScript.instance.orientationObj.forward * -2.5f));
                }
                else
                {
                    agent.SetDestination(player.position);
                }

                stalkTime += Time.deltaTime;
                break;

            case RatState.chasing:
                if (!isAttacking)
                {
                    moveState = RatMovementState.running;
                    agent.SetDestination(player.position);
                }

                chasingTime += Time.deltaTime;
                attackCd += Time.deltaTime;

                if (Distance() < 3 && !isAttacking)
                {
                    attackRoutine = StartCoroutine(Attack());
                }

                break;

            case RatState.fleeting:
                moveState = RatMovementState.running;
                break;

            case RatState.venting:
                moveState = RatMovementState.idle;
                VentUpdate();
                break;
        }
    }

    private void UpdMoveState()
    {
        if (isStunned || isAttacking) return;

        if (moveState == RatMovementState.idle)
        {
            animator.SetBool("Walking", false);
            animator.SetBool("Running", false);
            agent.speed = 0;
            agent.acceleration = 100;
        }
        else if (moveState == RatMovementState.walking)
        {
            animator.SetBool("Walking", true);
            animator.SetBool("Running", false);
            agent.speed = 3;
            agent.acceleration = 10;
        }
        else if (moveState == RatMovementState.running)
        {
            animator.SetBool("Walking", false);
            animator.SetBool("Running", true);
            agent.speed = 6;
            agent.acceleration = 40;
        }
    }

    private IEnumerator Attack()
    {
        if (isAttacking || attackCd < attackCooldown) yield break;
        isAttacking = true;

        animator.SetBool("Walking", false);
        animator.SetBool("Running", false);
        agent.speed = 0;
        agent.acceleration = 100;

        Vector3 lookPos = player.position - transform.position;
        lookPos.y = 0f;
        transform.rotation = Quaternion.LookRotation(lookPos);

        Vector3 dir = (player.position - transform.position).normalized;
        dir.y = 0.8f;

        agent.enabled = false;

        yield return new WaitForSeconds(0.25f);

        if (Player.instance.usingMenu)
        {
            StopAllSFX();
            jumpVL.Play();

            yield return new WaitForSeconds(2f);
        }

        canKill = true;
        rb.AddForce(dir * jumpPower, ForceMode.Impulse);

        StopAllSFX();
        jumpVL.Play();

        yield return new WaitForSeconds(1.5f);

        canKill = false;

        agent.enabled = true;
        agent.Warp(transform.position);

        isAttacking = false;
        attackCd = 0;
    }

    public bool HitWithBat()
    {
        if (isStunned || ratState == RatState.fleeting || ratState == RatState.venting) return false;
        StartCoroutine(StunRoutine());
        return true;
    }

    private IEnumerator StunRoutine()
    {
        isStunned = true;

        if (attackRoutine != null)
        {
            StopCoroutine(attackRoutine);
            canKill = false;
            isAttacking = false;
            attackCd = 0;
        }

        animator.SetBool("Walking", false);
        animator.SetBool("Running", false);
        agent.speed = 0;
        agent.acceleration = 100;

        agent.enabled = false;

        Vector3 dir = (transform.position - player.position).normalized;
        dir.y = 0.5f;

        rb.linearVelocity = Vector3.zero;
        rb.AddForce(dir * jumpPower, ForceMode.Impulse);

        StopAllSFX();
        hurtVL.Play();

        yield return new WaitForSeconds(stunTime);

        rb.linearVelocity = Vector3.zero;

        agent.enabled = true;
        agent.Warp(transform.position);

        isStunned = false;

        lives -= 1;

        if (lives <= 0 && ratState != RatState.fleeting)
        {
            RestartState(RatState.fleeting);
            yield break;
        }

        if (ratState != RatState.fleeting)
            RestartState(RatState.chasing);
    }

    private void StopAllSFX()
    {
        chasingVL.Stop();
        fleetingVL.Stop();
        jumpVL.Stop();
        hurtVL.Stop();
    }

    public void Scare()
    {
        RestartState(RatState.fleeting);
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (!canKill) return;

        if (collision.gameObject.CompareTag("Player"))
        {
            Player.instance.Kill("Rat");
            canKill = false;
        }
    }
}
