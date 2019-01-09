defmodule Neuron do
  defstruct [:id, :cortex_id, :activation_function, :input_ids_and_bias, :output_ids]

  def gen(exoself_pid, node) do
    Node.spawn(node, __MODULE__, :loop, [exoself_pid])
  end

  def loop(exoself_pid) when is_pid(exoself_pid) do
    receive do
      {^exoself_pid, {id, cortex_pid, activation_function, input_pids_and_bias, output_pids}} ->
        loop(%{
          id: id,
          cortex_pid: cortex_pid,
          activation_function: activation_function,
          input_pids_and_bias: {input_pids_and_bias, input_pids_and_bias},
          output_pids: output_pids,
          acc: 0
        })
    end
  end

  def loop(
        state = %{
          id: id,
          cortex_pid: cortex_pid,
          input_pids_and_bias:
            {[{input_pid, weights} | rest_of_input_pids_and_bias], all_input_ids_and_bias},
          acc: acc
        }
      ) do
    receive do
      {^input_pid, :forward, input} ->
        result = dot(input, weights, 0)

        loop(%{
          state
          | input_pids_and_bias: {rest_of_input_pids_and_bias, all_input_ids_and_bias},
            acc: result + acc
        })

      {^cortex_pid, :get_backup} ->
        send(cortex_pid, {self(), id, all_input_ids_and_bias})
        loop(state)

      {^cortex_pid, :terminate} ->
        :ok
    end
  end

  def loop(
        state = %{
          activation_function: activation_function,
          input_pids_and_bias: {[bias], all_input_ids_and_bias},
          output_pids: output_pids,
          acc: acc
        }
      ) do
    output = apply(__MODULE__, activation_function, [acc + bias])
    for output_pid <- output_pids, do: send(output_pid, {self(), :forward, [output]})

    loop(%{
      state
      | input_pids_and_bias: {all_input_ids_and_bias, all_input_ids_and_bias},
        acc: 0
    })
  end

  def loop(
        state = %{
          activation_function: activation_function,
          input_pids_and_bias: {[], all_input_ids_and_bias},
          output_pids: output_pids,
          acc: acc
        }
      ) do
    output = apply(__MODULE__, activation_function, [acc])
    for output_pid <- output_pids, do: send(output_pid, {self(), :forward, [output]})

    loop(%{
      state
      | input_pids_and_bias: {all_input_ids_and_bias, all_input_ids_and_bias},
        acc: 0
    })
  end

  def tanh(val) do
    :math.tanh(val)
  end

  defp dot([i | input], [w | weights], acc) do
    dot(input, weights, i * w + acc)
  end

  defp dot([], [], acc) do
    acc
  end
end
