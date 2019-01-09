defmodule Exoself do
  def map do
    map(:ffnn)
  end

  def map(filename) do
    genotype = Term.fetch(filename)
    spawn(__MODULE__, :map, [filename, genotype])
  end

  def map(filename, genotype) do
    ids_and_pids = :ets.new(:ids_and_pids, [:set, :private])
    [cortex | cerebral_units] = genotype
    sensor_ids = cortex.sensor_ids
    actuator_ids = cortex.actuator_ids
    neuron_ids = cortex.neuron_ids

    spawn_cerebral_units(ids_and_pids, Cortex, [cortex.id])
    spawn_cerebral_units(ids_and_pids, Sensor, sensor_ids)
    spawn_cerebral_units(ids_and_pids, Actuator, actuator_ids)
    spawn_cerebral_units(ids_and_pids, Neuron, neuron_ids)

    link_cerebral_units(cerebral_units, ids_and_pids)
    link_cortex(cortex, ids_and_pids)
    cortex_pid = :ets.lookup_element(ids_and_pids, cortex.id, 2)

    receive do
      {^cortex_pid, :backup, neuron_ids_and_weights} ->
        updated_genotype = update_genotype(ids_and_pids, genotype, neuron_ids_and_weights)
        Term.store(updated_genotype, filename)
        IO.puts("Finished updating to file: #{filename}")
    end
  end

  def spawn_cerebral_units(ids_and_pids, cerebral_unit_type, [id | ids]) do
    pid = apply(cerebral_unit_type, :gen, [self(), node()])
    :ets.insert(ids_and_pids, {id, pid})
    :ets.insert(ids_and_pids, {pid, id})
    spawn_cerebral_units(ids_and_pids, cerebral_unit_type, ids)
  end

  def spawn_cerebral_units(_ids_and_pids, _cerebral_unit_type, []) do
    true
  end

  def link_cerebral_units(
        [sensor = %Sensor{} | rest_of_units],
        ids_and_pids
      ) do
    sensor_pid = :ets.lookup_element(ids_and_pids, sensor.id, 2)
    cortex_pid = :ets.lookup_element(ids_and_pids, sensor.cortex_id, 2)
    fanout_pids = for id <- sensor.fanout_ids, do: :ets.lookup_element(ids_and_pids, id, 2)

    send(
      sensor_pid,
      {self(), {sensor.id, cortex_pid, sensor.name, sensor.vector_length, fanout_pids}}
    )

    link_cerebral_units(rest_of_units, ids_and_pids)
  end

  def link_cerebral_units(
        [actuator = %Actuator{} | rest_of_units],
        ids_and_pids
      ) do
    actuator_pid = :ets.lookup_element(ids_and_pids, actuator.id, 2)
    cortex_pid = :ets.lookup_element(ids_and_pids, actuator.cortex_id, 2)
    fanin_pids = for id <- actuator.fanin_ids, do: :ets.lookup_element(ids_and_pids, id, 2)

    send(
      actuator_pid,
      {self(), {actuator.id, cortex_pid, actuator.name, fanin_pids}}
    )

    link_cerebral_units(rest_of_units, ids_and_pids)
  end

  def link_cerebral_units(
        [neuron = %Neuron{} | rest_of_units],
        ids_and_pids
      ) do
    neuron_pid = :ets.lookup_element(ids_and_pids, neuron.id, 2)
    cortex_pid = :ets.lookup_element(ids_and_pids, neuron.cortex_id, 2)

    input_pids_and_bias =
      convert_ids_and_bias_to_pids_and_bias(ids_and_pids, neuron.input_ids_and_bias, [])

    output_pids = for id <- neuron.output_ids, do: :ets.lookup_element(ids_and_pids, id, 2)

    send(
      neuron_pid,
      {self(),
       {neuron.id, cortex_pid, neuron.activation_function, input_pids_and_bias, output_pids}}
    )

    link_cerebral_units(rest_of_units, ids_and_pids)
  end

  def link_cerebral_units([], _ids_and_pids) do
    :ok
  end

  Z

  def link_cortex(cortex, ids_and_pids) do
    cortex_pid = :ets.lookup_element(ids_and_pids, cortex.id, 2)

    sensor_pids =
      for sensor_id <- cortex.sensor_ids do
        :ets.lookup_element(ids_and_pids, sensor_id, 2)
      end

    actuator_pids =
      for actuator_id <- cortex.actuator_ids do
        :ets.lookup_element(ids_and_pids, actuator_id, 2)
      end

    neuron_pids =
      for neuron_id <- cortex.neuron_ids do
        :ets.lookup_element(ids_and_pids, neuron_id, 2)
      end

    send(cortex_pid, {self(), {cortex.id, sensor_pids, actuator_pids, neuron_pids}, 1000})
  end

  def update_genotype(ids_and_pids, genotype, [{neuron_id, pids_and_bias} | weights_and_bias]) do
    IO.puts("neuron_id: #{inspect(neuron_id)}")
    IO.puts("genotype: #{inspect(genotype)}")

    IO.puts("pids_and_bias: #{inspect(pids_and_bias)}")

    updated_input_ids_and_bias =
      convert_pids_and_bias_to_ids_and_bias(ids_and_pids, pids_and_bias, [])

    neuron_index =
      Enum.find_index(genotype, fn unit ->
        case unit do
          %Neuron{id: ^neuron_id} -> true
          _ -> false
        end
      end)

    neuron = Enum.at(genotype, neuron_index)
    updated_neuron = %Neuron{neuron | input_ids_and_bias: updated_input_ids_and_bias}

    updated_genotype = List.replace_at(genotype, neuron_index, updated_neuron)

    IO.puts("Neuron: #{inspect(neuron)}")
    IO.puts("Updated Neuron: #{inspect(updated_neuron)}")
    IO.puts("Genotype: #{inspect(genotype)}")
    IO.puts("Updated Genotype: #{inspect(updated_genotype)}")
    update_genotype(ids_and_pids, updated_genotype, weights_and_bias)
  end

  def update_genotype(_ids_and_pids, genotype, []) do
    genotype
  end

  defp convert_ids_and_bias_to_pids_and_bias(_ids_and_pids, [{:bias, bias}], acc) do
    :lists.reverse([bias | acc])
  end

  defp convert_ids_and_bias_to_pids_and_bias(
         ids_and_pids,
         [{id, weights} | ids_and_bias],
         acc
       ) do
    pid = :ets.lookup_element(ids_and_pids, id, 2)
    acc = [{pid, weights} | acc]

    convert_ids_and_bias_to_pids_and_bias(ids_and_pids, ids_and_bias, acc)
  end

  defp convert_pids_and_bias_to_ids_and_bias(
         ids_and_pids,
         [{pid, weights} | pids_and_bias],
         acc
       ) do
    id = :ets.lookup_element(ids_and_pids, pid, 2)
    acc = [{id, weights} | acc]

    convert_pids_and_bias_to_ids_and_bias(ids_and_pids, pids_and_bias, acc)
  end

  defp convert_pids_and_bias_to_ids_and_bias(_ids_and_pids, [bias], acc) do
    :lists.reverse([{:bias, bias} | acc])
  end
end
