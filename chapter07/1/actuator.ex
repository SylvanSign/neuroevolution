defmodule Actuator do
  defstruct [:id, :cortex_id, :name, :vector_length, :fanin_ids]

  def gen(exoself_pid, node) do
    Node.spawn(node, __MODULE__, :loop, [exoself_pid])
  end

  def loop(exoself_pid) when is_pid(exoself_pid) do
    receive do
      {^exoself_pid, {id, cortex_pid, actuator_name, fanin_pids}} ->
        loop(%{
          id: id,
          cortex_pid: cortex_pid,
          actuator_name: actuator_name,
          fanin_pids: {fanin_pids, fanin_pids},
          acc: []
        })
    end
  end

  def loop(
        state = %{
          cortex_pid: cortex_pid,
          fanin_pids: {[from_pid | rest_of_fanin_pids_to_check], all_fanin_pids},
          acc: acc
        }
      ) do
    receive do
      {^from_pid, :forward, input} ->
        loop(%{
          state
          | fanin_pids: {rest_of_fanin_pids_to_check, all_fanin_pids},
            acc: input ++ acc
        })

      {^cortex_pid, :terminate} ->
        :ok
    end
  end

  def loop(
        state = %{
          cortex_pid: cortex_pid,
          actuator_name: actuator_name,
          fanin_pids: {[], all_fanin_pids},
          acc: acc
        }
      ) do
    apply(__MODULE__, actuator_name, [:lists.reverse(acc)])
    send(cortex_pid, {self(), :sync})

    loop(%{
      state
      | fanin_pids: {all_fanin_pids, all_fanin_pids},
        acc: []
    })
  end

  def log(result) do
    IO.puts("Actuator.log(result): #{inspect(result)}")
  end
end
