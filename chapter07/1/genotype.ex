defmodule Genotype do
  def construct(sensor_name, actuator_name, hidden_layer_densities) do
    construct(:ffnn, sensor_name, actuator_name, hidden_layer_densities)
  end

  def construct(filename, sensor_name, actuator_name, hidden_layer_densities) do
    sensor = create_sensor(sensor_name)
    actuator = create_actuator(actuator_name)
    output_vector_length = actuator.vector_length
    layer_densities = hidden_layer_densities ++ [output_vector_length]
    cortex_id = {:cortex, generate_id()}

    neurons = create_neuro_layers(cortex_id, sensor, actuator, layer_densities)
    input_layer = List.first(neurons)
    output_layer = List.last(neurons)
    first_layer_neuron_ids = for neuron <- input_layer, do: neuron.id
    last_layer_neuron_ids = for neuron <- output_layer, do: neuron.id
    neuron_ids = for neuron <- List.flatten(neurons), do: neuron.id

    sensor = %Sensor{sensor | cortex_id: cortex_id, fanout_ids: first_layer_neuron_ids}
    actuator = %Actuator{actuator | cortex_id: cortex_id, fanin_ids: last_layer_neuron_ids}
    cortex = create_cortex(cortex_id, [sensor.id], [actuator.id], neuron_ids)
    genotype = List.flatten([cortex, sensor, actuator | neurons])
    save_genotype(filename, genotype)
  end

  def create_sensor(:rng) do
    %Sensor{id: {:sensor, generate_id()}, name: :rng, vector_length: 2}
  end

  def create_sensor(name) do
    Process.exit("System does not yet support a sensor by the name: #{name}")
  end

  def create_actuator(:log) do
    %Actuator{id: {:actuator, generate_id()}, name: :log, vector_length: 1}
  end

  def create_actuator(name) do
    Process.exit("System does not yet support an actuator by the name: #{name}")
  end

  def create_neuro_layers(cortex_id, sensor, actuator, layer_densities) do
    input_ids_and_bias = [{sensor.id, sensor.vector_length}]
    total_layers = length(layer_densities)
    [first_layer_neuron_count | rest_of_layer_densities] = layer_densities
    neuron_ids = for id <- generate_ids(first_layer_neuron_count, []), do: {:neuron, {1, id}}

    create_neuro_layers(%{
      layer_densities: rest_of_layer_densities,
      cortex_id: cortex_id,
      actuator_id: actuator.id,
      layer_index: 1,
      total_layers: total_layers,
      input_ids_and_bias: input_ids_and_bias,
      neuron_ids: neuron_ids,
      acc: []
    })
  end

  def create_neuro_layers(%{
        layer_densities: [first_layer_neuron_count | rest_of_layer_densities],
        layer_index: layer_index,
        acc: acc,
        cortex_id: cortex_id,
        actuator_id: actuator_id,
        total_layers: total_layers,
        input_ids_and_bias: input_ids_and_bias,
        neuron_ids: neuron_ids
      }) do
    output_neuron_ids =
      for id <- generate_ids(first_layer_neuron_count, []) do
        {:neuron, {layer_index + 1, id}}
      end

    layer_neurons =
      create_neuro_layer(%{
        neuron_ids: neuron_ids,
        cortex_id: cortex_id,
        input_ids_and_bias: input_ids_and_bias,
        output_ids: output_neuron_ids,
        acc: []
      })

    next_input_ids_and_bias = for neuron_id <- neuron_ids, do: {neuron_id, 1}

    create_neuro_layers(%{
      layer_densities: rest_of_layer_densities,
      layer_index: layer_index + 1,
      acc: [layer_neurons | acc],
      cortex_id: cortex_id,
      actuator_id: actuator_id,
      total_layers: total_layers,
      input_ids_and_bias: next_input_ids_and_bias,
      neuron_ids: output_neuron_ids
    })
  end

  def create_neuro_layers(%{
        layer_densities: [],
        layer_index: total_layers,
        acc: acc,
        cortex_id: cortex_id,
        actuator_id: actuator_id,
        total_layers: total_layers,
        input_ids_and_bias: input_ids_and_bias,
        neuron_ids: neuron_ids
      }) do
    output_ids = [actuator_id]

    layer_neurons =
      create_neuro_layer(%{
        neuron_ids: neuron_ids,
        cortex_id: cortex_id,
        input_ids_and_bias: input_ids_and_bias,
        output_ids: output_ids,
        acc: []
      })

    Enum.reverse([layer_neurons | acc])
  end

  def create_neuro_layer(%{
        neuron_ids: [id | neuron_ids],
        cortex_id: cortex_id,
        input_ids_and_bias: input_ids_and_bias,
        output_ids: output_ids,
        acc: acc
      }) do
    neuron = create_neuron(input_ids_and_bias, id, cortex_id, output_ids)

    create_neuro_layer(%{
      neuron_ids: neuron_ids,
      cortex_id: cortex_id,
      input_ids_and_bias: input_ids_and_bias,
      output_ids: output_ids,
      acc: [neuron | acc]
    })
  end

  def create_neuro_layer(%{
        neuron_ids: [],
        acc: acc
      }) do
    acc
  end

  def create_neuron(input_ids_and_bias, id, cortex_id, output_ids) do
    proper_input_ids_and_bias = create_neural_input(input_ids_and_bias, [])

    %Neuron{
      id: id,
      cortex_id: cortex_id,
      activation_function: :tanh,
      input_ids_and_bias: proper_input_ids_and_bias,
      output_ids: output_ids
    }
  end

  def create_neural_input([{input_id, input_vector_length} | input_ids_and_bias], acc) do
    weights = create_neural_weights(input_vector_length, [])
    create_neural_input(input_ids_and_bias, [{input_id, weights} | acc])
  end

  def create_neural_input([], acc) do
    Enum.reverse([{:bias, :rand.uniform() - 0.5} | acc])
  end

  def create_neural_weights(0, acc) do
    acc
  end

  def create_neural_weights(index, acc) do
    weight = :rand.uniform() - 0.5
    create_neural_weights(index - 1, [weight | acc])
  end

  def generate_ids(0, acc) do
    acc
  end

  def generate_ids(index, acc) do
    id = generate_id()
    generate_ids(index - 1, [id | acc])
  end

  def generate_id() do
    System.unique_integer([:positive])
  end

  def create_cortex(cortex_id, sensor_ids, actuator_ids, neuron_ids) do
    %Cortex{
      id: cortex_id,
      sensor_ids: sensor_ids,
      actuator_ids: actuator_ids,
      neuron_ids: neuron_ids
    }
  end

  def save_genotype(filename, genotype) do
    table_id = :ets.new(filename, [:public, :set])
    for element <- genotype, do: :ets.insert(table_id, {element.id, element})
    :ets.tab2file(table_id, filename)
  end

  def save_to_file(genotype, filename) do
    :ets.tab2file(genotype, filename)
  end

  def load_from_file(filename) do
    {:ok, table_id} = :ets.file2tab(filename)
    table_id
  end

  def read(table_id, key) do
    [{_type, unit}] = :ets.lookup(table_id, key)
    unit
  end

  def write(table_id, unit) do
    :ets.insert(table_id, unit)
  end

  def print(filename) do
    genotype = load_from_file(filename)
    cortex = :ets.first(genotype)
    IO.inspect(cortex)

    Enum.each([cortex.sensor_ids, cortex.neuron_ids, cortex.actuator_ids], fn ids ->
      for id <- ids, do: IO.inspect(read(genotype, id))
    end)
  end
end
