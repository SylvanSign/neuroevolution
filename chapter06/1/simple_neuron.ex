defmodule SimpleNeuron do
  def create do
    weights = Enum.map(1..3, fn _ -> :rand.uniform() - 0.5 end)
    pid = spawn(__MODULE__, :loop, [weights])
    Process.register(pid, __MODULE__)
  end

  def loop(weights) do
    receive do
      {from, input} ->
        IO.puts("****Processing****")
        IO.puts(" Input: #{inspect(input)}")
        IO.puts(" Using Weights: #{inspect(weights)}")
        dot_product = dot(input, weights, 0)
        output = [:math.tanh(dot_product)]
        send(from, {:result, output})
        loop(weights)
    end
  end

  def sense(signal) do
    if is_list(signal) and length(signal) == 2 do
      send(__MODULE__, {self(), signal})

      receive do
        {:result, output} ->
          IO.puts("Output: #{inspect(output)}")
      end
    else
      IO.puts("The signal must be a list of length 2")
    end
  end

  defp dot([i | input], [w | weights], acc) do
    dot(input, weights, i * w + acc)
  end

  defp dot([], [bias], acc) do
    acc + bias
  end
end
