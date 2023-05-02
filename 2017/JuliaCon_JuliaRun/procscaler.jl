using AMQPClient
using JuliaRun
using JuliaRun.Scaler

const EXCG_DIRECT = "amq.direct"
const QUEUE = "workq"
const WINDOW_SIZE = 20
const CHECK_INTERVAL = 10
const AMQP_PORT = 30011

function start_queue(ctx)
    queue = nothing
    # unless the queue is already running
    for job in list(ctx)
        (job.name == "mq") && (queue = job; break)
    end
    if queue === nothing
        # bring up a queue
        queue = MessageQ("mq", "", "juliarun"; external=true, ports=Dict("amqp"=>(5672,AMQP_PORT)))
        submit(ctx, queue)
    end
    queue
end

function setup_q(; virtualhost="/", host="localhost", port=AMQP_PORT, auth_params=AMQPClient.DEFAULT_AUTH_PARAMS)
    conn = connection(;virtualhost=virtualhost, host=host, port=port, auth_params=auth_params)
    chan1 = channel(conn, AMQPClient.UNUSED_CHANNEL, true)
    queue_declare(chan1, QUEUE)
    queue_bind(chan1, QUEUE, EXCG_DIRECT, "workq")
    conn, chan1
end

function publish_work(; kwargs...)
    sleep_time = 10
    nmsgs = 10

    #println("Sending $nmsgs messages to sleep $sleep_time seconds...")

    conn, chan1 = setup_q(; kwargs...)
    M = Message(convert(Array{UInt8}, string(sleep_time)); content_type="application/octet-stream", delivery_mode=PERSISTENT)

    for i in 1:nmsgs
        basic_publish(chan1, M; exchange=EXCG_DIRECT, routing_key="workq")
    end

    sleep(5)
    close(conn)
    println("Done")
end
