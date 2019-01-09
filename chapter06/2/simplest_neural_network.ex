defmodule SimplestNeuralNetwork do
  @num_weights 3

  def create do
    weights = Enum.map(1..@num_weights, fn _ -> :rand.uniform() - 0.5 end)

    neuron_pid = spawn(__MODULE__, :neuron, [weights, nil, nil])
    sensor_pid = spawn(__MODULE__, :sensor, [neuron_pid])
    actuator_pid = spawn(__MODULE__, :actuator, [neuron_pid])

    send(neuron_pid, {:init, sensor_pid, actuator_pid})
    cortex_pid = spawn(__MODULE__, :cortex, [sensor_pid, neuron_pid, actuator_pid])
    Process.register(cortex_pid, :cortex)
  end

  def neuron(weights, sensor_pid, actuator_pid) do
    receive do
      {^sensor_pid, :forward, input} ->
        IO.puts("****Thinking****")
        IO.puts(" Input: #{inspect(input)}")
        IO.puts(" with Weights: #{inspect(weights)}")
        dot_product = dot(input, weights, 0)
        output = [:math.tanh(dot_product)]
        send(actuator_pid, {self(), :forward, output})
        neuron(weights, sensor_pid, actuator_pid)

      {:init, new_sensor_pid, new_actuator_pid} ->
        neuron(weights, new_sensor_pid, new_actuator_pid)

      :terminate ->
        :ok
    end
  end

  def sensor(neuron_pid) do
    receive do
      :sync ->
        sensory_signal = Enum.map(1..(@num_weights - 1), fn _ -> :rand.uniform() end)
        IO.puts("****Sensing****")
        IO.puts(" Signal from the environment: #{inspect(sensory_signal)}")
        send(neuron_pid, {self(), :forward, sensory_signal})
        sensor(neuron_pid)

      :terminate ->
        :ok
    end
  end

  def actuator(neuron_pid) do
    receive do
      {^neuron_pid, :forward, control_signal} ->
        IO.puts("****Acting****")
        IO.puts(" Using #{inspect(control_signal)} to act on environment")
        actuator(neuron_pid)

      :terminate ->
        :ok
    end
  end

  def cortex(sensor_pid, neuron_pid, actuator_pid) do
    receive do
      :sense_think_act ->
        send(sensor_pid, :sync)
        cortex(sensor_pid, neuron_pid, actuator_pid)

      :terminate ->
        Enum.each([sensor_pid, neuron_pid, actuator_pid], fn pid -> send(pid, :terminate) end)
        :ok
    end
  end

  defp dot([i | input], [w | weights], acc) do
    dot(input, weights, i * w + acc)
  end

  defp dot([], [bias], acc) do
    acc + bias
  end
end
