defmodule Sensor do
  defstruct [:id, :cortex_id, :name, :vector_length, :fanout_ids]

  def gen(exoself_pid, node) do
    Node.spawn(node, __MODULE__, :loop, [exoself_pid])
  end

  def loop(exoself_pid) when is_pid(exoself_pid) do
    receive do
      {^exoself_pid, {id, cortex_pid, sensor_name, vector_length, fanout_pids}} ->
        loop(%{
          id: id,
          cortex_pid: cortex_pid,
          sensor_name: sensor_name,
          vector_length: vector_length,
          fanout_pids: fanout_pids
        })
    end
  end

  def loop(
        state = %{
          cortex_pid: cortex_pid,
          sensor_name: sensor_name,
          vector_length: vector_length,
          fanout_pids: fanout_pids
        }
      ) do
    receive do
      {^cortex_pid, :sync} ->
        sensory_vector = apply(__MODULE__, sensor_name, [vector_length])
        for pid <- fanout_pids, do: send(pid, {self(), :forward, sensory_vector})
        loop(state)

      {^cortex_pid, :terminate} ->
        :ok
    end
  end

  def rng(vector_length) do
    _rng(vector_length, [])
  end

  defp _rng(0, acc) do
    acc
  end

  defp _rng(vector_length, acc) do
    _rng(vector_length - 1, [:rand.uniform() | acc])
  end
end
