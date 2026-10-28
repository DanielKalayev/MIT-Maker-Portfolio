using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

public enum MonsterState { idle, wandering, chasing, angered, fleeing }
public class Monster : MonoBehaviour
{
    public static Monster instance;

    [Header("AI")]
    [SerializeField] private Transform wanderPointsParent;
    private List<Transform> wanderPoints;
    private NavMeshAgent agent;
    private Transform player;

    [Header("Settings")]
    [SerializeField] private float sightDistance = 12f;
    private int wanderIndex = 0;
    [SerializeField] private float sightAngle = 100f;

    [SerializeField] private float idleTimeMin = 3f;
    [SerializeField] private float idleTimeMax = 9f;
    private float idleTime = 0;

    [SerializeField] private float angryTime = 20f;
    [SerializeField] private float chaseMemoryTime = 3f;
    private float lastSeenTimer = 0f;

    [SerializeField] private float trappedTime = 3f;
    private float timeSpentTrapped = 0f;

    [Space]

    [SerializeField] private float distanceToDoor = 7;
    [SerializeField] private float doorCooldown = 5;
    private float doorTime = 0f;

    [Header("Animation")]
    [SerializeField] private Animator animator;
    [SerializeField] private Footsteps footStepCheck;
    public float animSpeed = 1f;

    [Header("Audio")]
    [SerializeField] private AudioClip[] footClip;
    private bool footstepEnabled = true;

    [SerializeField] private AudioClip scream;
    private AudioSource currentScream;

    [Header("States")]
    public MonsterState state { get; private set; }

    [Header("Stun")]
    [SerializeField] private float stunTime = 2f;
    [SerializeField] private float knockbackForce = 15f;

    private Rigidbody rb;
    private bool isStunned = false;

    private int lives = 3;

    private void Awake()
    {
        instance = this;
        agent = GetComponent<NavMeshAgent>();
        rb = GetComponent<Rigidbody>();
    }

    void Start()
    {
        player = Player.instance.transform;
        agent.isStopped = false;
        doorTime = doorCooldown;

        wanderPoints = new List<Transform>();
        foreach (Transform t in wanderPointsParent)
            wanderPoints.Add(t);

        state = MonsterState.idle;
        StartCoroutine(BehaviorLoop());

        footStepCheck.Footstep += (int num) => StepSFX(num);
    }


    private void Update()
    {
        UpdMoveState();

        if (agent.velocity.sqrMagnitude > 0.1f && (footstepEnabled || state == MonsterState.chasing))
            transform.forward = agent.velocity.normalized;
        
        if (footstepEnabled && doorTime <= doorCooldown)
            doorTime += Time.deltaTime;
    }

    private void StepSFX(int num)
    {
        if (!footstepEnabled && (state != MonsterState.chasing || state != MonsterState.angered)) return;
        SFXManager.instance.PlaySFXClip(footClip[num], transform, 5f, true, 40);
    }

    private void TargetPlayer()
    {
        if (!agent.isActiveAndEnabled) return;
        Vector3 target = KeycardDoor.GetPlayerRoomPos(transform.position);
        if (target == Vector3.zero)
        {
            target = player.transform.position;
        }
        agent.SetDestination(target);
    }

    private Vector3 GetRandomSpot()
    {
        if (!agent.isActiveAndEnabled) return transform.position;

        List<Transform> availableSpots = new List<Transform>(wanderPoints);

        while (availableSpots.Count > 0)
        {
            int index = Random.Range(0, availableSpots.Count);
            Transform chosen = availableSpots[index];

            NavMeshPath path = new NavMeshPath();
            agent.CalculatePath(chosen.position, path);

            if (path.status == NavMeshPathStatus.PathComplete)
            {
                return chosen.position;
            }

            availableSpots.RemoveAt(index);
        }

        return transform.position;
    }

    private Vector3 GetFurthestSpot()
    {
        if (!agent.isActiveAndEnabled)
            return transform.position;

        Vector3 bestPosition = transform.position;
        float farthestDistance = 0f;

        foreach (Transform spot in wanderPoints)
        {
            NavMeshPath path = new NavMeshPath();
            agent.CalculatePath(spot.position, path);

            if (path.status == NavMeshPathStatus.PathComplete)
            {
                float dist = Vector3.Distance(transform.position, spot.position);

                if (dist > farthestDistance)
                {
                    farthestDistance = dist;
                    bestPosition = spot.position;
                }
            }
        }

        return bestPosition;
    }

    public IEnumerator BehaviorLoop()
    {
        while (true)
        {
            if (isStunned)
            {
                yield return null; 
                continue;
            }

            if (CanSeePlayer() && state != MonsterState.angered && state != MonsterState.fleeing)
                state = MonsterState.chasing;

            switch (state)
            {
                case MonsterState.idle:

                    if (!footstepEnabled) 
                    {
                        idleTime = 0;
                        break;
                    }
                        
                    idleTime -= Time.deltaTime;

                    if (idleTime <= 0f)
                    {
                        RestartWander();
                    }

                    break;

                case MonsterState.wandering:
                    WanderUpdate();
                    break;

                case MonsterState.chasing:
                    ChaseUpdate();
                    break;
                case MonsterState.angered:
                    AngerUpdate();
                    break;
                case MonsterState.fleeing:
                    FleeUpdate();
                    break;
            }

            yield return null;
        }
    }

    void ChaseUpdate()
    {
        if (CanSeePlayer())
        {
            lastSeenTimer = chaseMemoryTime;
        }
        else
        {
            CheckForDoor();
            lastSeenTimer -= Time.deltaTime;
        }

        //move toward last seen location
        TargetPlayer();

        //when memory ends stop chasing
        if (lastSeenTimer <= 0f)
            state = MonsterState.wandering;
    }

    void AngerUpdate()
    {
        if (CanSeePlayer())
        {
            lastSeenTimer = angryTime;
        }
        else
        {
            CheckForDoor(true);
            lastSeenTimer -= Time.deltaTime;
        }

        TargetPlayer();

        if (lastSeenTimer <= 0f)
        {
            CancelAngerSFX();
            state = MonsterState.wandering;
        }
    }

    private KeycardDoor LockedInRoom()
    {
        KeycardDoor door = KeycardDoor.GetDoorWithinRange(transform.position, distanceToDoor * 2);
        if (door != null && !door.doorOpen && !door.PlayerIsInRoom() && door.PosIsInRoom(transform.position))
        {
            return door;
        }
        return null;
    }

    private bool justRestartedWander = false;

    private void RestartWander()
    {
        if (!agent.isActiveAndEnabled) return;
        Vector3 target = GetRandomSpot();
        agent.SetDestination(target);
        CancelAngerSFX();
        state = MonsterState.wandering;
        justRestartedWander = true;
    }

    private void RestartFlee()
    {
        if (!agent.isActiveAndEnabled) return;
        Vector3 target = GetFurthestSpot(); 
        agent.SetDestination(target);
        state = MonsterState.fleeing;
        justRestartedWander = true;
    }

    private void WanderUpdate()
    {
        CheckForDoor();

        if (justRestartedWander)
        {
            //for when restart wander
            justRestartedWander = false;
        }
        else
        {
            if (!footstepEnabled) return;

            if (!agent.hasPath || agent.remainingDistance < 0.5f)
            {
                state = MonsterState.idle;
                idleTime = Random.Range(idleTimeMin, idleTimeMax);
                return;
            }
        }

        //trapped inside door frees him
        KeycardDoor lockedInDoor = LockedInRoom();
        if (lockedInDoor != null)
            timeSpentTrapped += Time.deltaTime;
        else
            timeSpentTrapped = 0f;

        if (timeSpentTrapped > trappedTime)
            lockedInDoor.ForceDoorOpen();

        if (agent.pathStatus != NavMeshPathStatus.PathComplete)
            agent.SetDestination(wanderPoints[wanderIndex].position);
    }

    private void FleeUpdate()
    {

        if (justRestartedWander)
        {
            justRestartedWander = false;
        }
        else
        {
            if (!footstepEnabled) return;

            if (!agent.hasPath || agent.remainingDistance < 0.5f)
            {
                state = MonsterState.idle;
                idleTime = Random.Range(idleTimeMin, idleTimeMax);
                lives = 3;
                CancelAngerSFX();
                return;
            }
        }

        KeycardDoor lockedInDoor = LockedInRoom();
        if (lockedInDoor != null)
            timeSpentTrapped += Time.deltaTime * 2;
        else
            timeSpentTrapped = 0f;

        if (timeSpentTrapped > trappedTime)
            lockedInDoor.ForceDoorOpen();

        if (agent.pathStatus != NavMeshPathStatus.PathComplete)
            agent.SetDestination(wanderPoints[wanderIndex].position);
    }

    private void CheckForDoor(bool angry = false)
    {
        KeycardDoor door = KeycardDoor.GetDoorWithinRange(transform.position, distanceToDoor);
        if (door != null && !door.doorOpen && !door.isBangingOnDoor && door.PlayerIsInRoom() &&
            !door.PosIsInRoom(transform.position) && footstepEnabled && doorTime > doorCooldown)
        {
            StartCoroutine(BangOnDoorRoutine(door, angry));
        }
    }

    private IEnumerator BangOnDoorRoutine(KeycardDoor door, bool angry)
    {
        footstepEnabled = false;
        state = MonsterState.idle;

        bool done = false;
        door.BangOnDoor(() => done = true, angry);

        //tp him to the door
        transform.position = door.transform.position - door.transform.forward * 2f;
        transform.forward = door.transform.forward;

        yield return new WaitUntil(() => done);

        footstepEnabled = true;

        RestartWander();

        doorTime = angry ? -5f : 0f;
    }

    bool CanSeePlayer()
    {
        Vector3 dir = (player.position - transform.position);
        float dist = dir.magnitude;

        if (dist > sightDistance)
            return false;

        float angle = Vector3.Angle(transform.forward, dir);
        if (angle > sightAngle * 0.5f)
            return false;

        if (Physics.Raycast(transform.position, dir.normalized, out RaycastHit hit, sightDistance))
        {
            if (hit.transform != player)
                return false;
        }

        return true;
    }

    public void Anger()
    {
        state = MonsterState.angered;
        lastSeenTimer = angryTime;
        footstepEnabled = true;

        if (currentScream == null)
        currentScream = SFXManager.instance.CancelableSFX(scream, transform, 0.65f, true, 0, true, 33);
    }

    private void CancelAngerSFX()
    {
        if (currentScream != null)
            Destroy(currentScream);
    }

    public bool HitWithBat()
    {
        if (isStunned || state == MonsterState.fleeing) return false;
        StartCoroutine(StunRoutine());
        return true;
    }

    private IEnumerator StunRoutine()
    {
        isStunned = true;

        animator.SetBool("Walking", false);
        animator.SetFloat("WalkSpeed", 0);
        agent.speed = 0;
        agent.acceleration = 100;

        agent.enabled = false;

        Vector3 dir = (transform.position - player.position).normalized;
        dir.y = 0.2f;

        rb.linearVelocity = Vector3.zero;
        rb.AddForce(dir * knockbackForce, ForceMode.Impulse);

        yield return new WaitForSeconds(stunTime);

        rb.linearVelocity = Vector3.zero;

        agent.enabled = true;
        agent.Warp(transform.position);

        isStunned = false;
        
        if (Random.Range(1f, 100f) < 60)
        {
            lives -= 1;
            if (lives <= 0)
            {
                RestartFlee();
            }
        }

        if (state != MonsterState.fleeing)
        Anger();
    }

    private void UpdMoveState()
    {
        if (isStunned) return;

        switch (state)
        {
            case (MonsterState.idle):
                animator.SetBool("Walking", false);
                
                agent.speed = 0;
                agent.acceleration = 100;
                break;

            case (MonsterState.wandering):

                animator.SetBool("Walking", true);
                agent.speed = 4;
                agent.acceleration = 10;
                animSpeed = 1f;
                break;

            case (MonsterState.chasing):
                animator.SetBool("Walking", true);
                agent.speed = 8;
                agent.acceleration = 40;
                animSpeed = 2.5f;
                break;

            case (MonsterState.angered): case (MonsterState.fleeing):
                animator.SetBool("Walking", true);
                agent.speed = 12;
                agent.acceleration = 60;
                animSpeed = 4f;
                break;
        }

        animator.SetFloat("WalkSpeed", animSpeed);
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.transform == Player.instance.transform && (state == MonsterState.chasing || state == MonsterState.angered))
        {
            Player.instance.Kill("Monster");
        }
    }
}
