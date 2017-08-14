using AMQPClient
using JuliaRun

const EXCG_DIRECT = "amq.direct"
const QUEUE = "workq"
const AMQP_PORT = 30011

function setup_q(; virtualhost="/", host="localhost", port=AMQPClient.AMQP_DEFAULT_PORT, auth_params=AMQPClient.DEFAULT_AUTH_PARAMS)
    conn = connection(;virtualhost=virtualhost, host=host, port=port, auth_params=auth_params)
    chan1 = channel(conn, AMQPClient.UNUSED_CHANNEL, true)
    queue_declare(chan1, QUEUE)
    queue_bind(chan1, QUEUE, EXCG_DIRECT, "workq")
    conn, chan1
end

function messageq_worker(; kwargs...)
    conn, chan1 = setup_q(; kwargs...)
    recv_count = 0
    nomsg_count = 0

    while isopen(chan1)
        println("doing get")
        result = basic_get(chan1, QUEUE, false)
        if isnull(result)
            nomsg_count += 1
            if (nomsg_count % 10) == 0
                println("no messages $nomsg_count...")
            end
            sleep(1)
        else
            rcvd_msg = get(result)
            recv_count += 1
            #if (recv_count % 10) == 0
                println("received $recv_count...")
            #end

            # worker sleeps for N seconds
            sleep_time = parse(Int, String(rcvd_msg.data))
            basic_ack(chan1, rcvd_msg.delivery_tag)
            sleep(sleep_time)
        end
    end
    println("channel closed: $(chan1.closereason)")
end

messageq_worker(; host="mq-svc")
