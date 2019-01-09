defmodule Cortex do
  defstruct [:id, :sensor_ids, :actuator_ids, :neuron_ids]

  def gen(exoself_pid, node) do
    Node.spawn(node, __MODULE__, :loop, [exoself_pid])
  end

  def loop(exoself_pid) when is_pid(exoself_pid) do
    receive do
      {^exoself_pid, {id, sensor_pids, actuator_pids, neuron_pids}, total_steps} ->
        for sensor_pid <- sensor_pids, do: send(sensor_pid, {self(), :sync})

        loop(%{
          id: id,
          exoself_pid: exoself_pid,
          sensor_pids: sensor_pids,
          actuator_pids: {actuator_pids, actuator_pids},
          neuron_pids: neuron_pids,
          step: total_steps
        })
    end
  end

  def loop(%{
        step: 0,
        actuator_pids: {_actuator_pids_to_check, all_actuator_pids},
        id: id,
        exoself_pid: exoself_pid,
        sensor_pids: sensor_pids,
        neuron_pids: neuron_pids
      }) do
    IO.puts("Cortex: #{inspect(id)} is backing up and terminating.")
    neuron_ids_and_weights = get_backup(neuron_pids, [])
    send(exoself_pid, {self(), :backup, neuron_ids_and_weights})

    terminate(sensor_pids, all_actuator_pids, neuron_pids)
  end

  def loop(
        state = %{
          actuator_pids: {[actuator_pid | rest_of_actuator_pids_to_check], all_actuator_pids},
          id: id,
          sensor_pids: sensor_pids,
          neuron_pids: neuron_pids
        }
      ) do
    receive do
      {^actuator_pid, :sync} ->
        loop(%{state | actuator_pids: {rest_of_actuator_pids_to_check, all_actuator_pids}})

      :terminate ->
        IO.puts("Cortex: #{inspect(id)} is terminating.")
        terminate(sensor_pids, all_actuator_pids, neuron_pids)
    end
  end

  def loop(
        state = %{
          step: step,
          actuator_pids: {[], all_actuator_pids},
          sensor_pids: sensor_pids
        }
      ) do
    for pid <- sensor_pids, do: send(pid, {self(), :sync})

    loop(%{
      state
      | actuator_pids: {all_actuator_pids, all_actuator_pids},
        step: step - 1
    })
  end

  def get_backup([neuron_pid | neuron_pids], acc) do
    send(neuron_pid, {self(), :get_backup})

    receive do
      {^neuron_pid, neuron_id, weight_tuples} ->
        get_backup(neuron_pids, [{neuron_id, weight_tuples} | acc])
    end
  end

  def get_backup([], acc) do
    acc
  end

  defp terminate(sensor_pids, all_actuator_pids, neuron_pids) do
    [sensor_pids, all_actuator_pids, neuron_pids]
    |> List.flatten()
    |> Enum.each(fn pid ->
      send(pid, {self(), :terminate})
    end)
  end
end
