defmodule Forth do
  @opaque evaluator :: Forth.Evaluator.t

  defmodule Evaluator do
    @type t :: __MODULE__
    defstruct stack: [],
              words: %{}
  end

  @doc """
  Create a new evaluator.
  """
  @spec new() :: evaluator
  def new() do
    %Evaluator{}
  end

  @doc """
  Evaluate an input string, updating the evaluator state.
  """
  @spec eval(evaluator, String.t) :: evaluator
  def eval(evaluator, s) do
    s
    |> tokenize()
    |> (&do_eval(evaluator, &1)).()
  end

  defp tokenize(s) do
    String.split(s, ~r/[\x{0000}\x{0001} \s\p{Zs}]+/u)
    #|> IO.inspect(label: "Tokens")
  end

  defp do_eval(evaluator, []) do
    evaluator
  end
  defp do_eval(%{words: words} = ev, [token | tokens]) do
    #IO.puts("Stack: #{Forth.format_stack(evaluator)} :: Token: #{token}")
    normalized_token = String.downcase(token)

    #IO.inspect(ev, label: "Evaluator")
    #IO.inspect([token | tokens], label: "Tokens")
    if Map.has_key?(words, normalized_token) do
      do_eval(ev, Map.fetch!(words, normalized_token) ++ tokens)
    else 
      {next_evaluator, next_tokens} = case normalized_token do
        "+" -> eval_add(ev, tokens)
        "-" -> eval_sub(ev, tokens)
        "*" -> eval_mul(ev, tokens)
        "/" -> eval_div(ev, tokens)
        ":" -> eval_def(ev, tokens)
        "dup" -> eval_dup(ev, tokens)
        "drop" -> eval_drop(ev, tokens)
        "swap" -> eval_swap(ev, tokens)
        "over" -> eval_over(ev, tokens)
        _   -> eval_push(ev, tokens, normalized_token)
      end
      do_eval(next_evaluator, next_tokens)
    end
  end

  defp eval_add(%{stack: [first, second | rest]} = ev, tokens) do
    result = second + first
    {%{ev | stack: [result | rest]}, tokens}
  end

  defp eval_sub(%{stack: [first, second | rest]} = ev, tokens) do
    result = second - first
    {%{ev | stack: [result | rest]}, tokens}
  end

  defp eval_mul(%{stack: [first, second | rest]} = ev, tokens) do
    result = second * first
    {%{ev | stack: [result | rest]}, tokens}
  end

  defp eval_div(%{stack: [0, _ | _rest]}, _tokens) do
    raise Forth.DivisionByZero
  end
  defp eval_div(%{stack: [first, second | rest]} = ev, tokens) do
    result = div(second, first)
    {%{ev | stack: [result | rest]}, tokens}
  end

  defp eval_dup(%{stack: []}, _tokens) do
    raise Forth.StackUnderflow
  end
  defp eval_dup(%{stack: [first | _rest] = stack} = ev, tokens) do
    {%{ev | stack: [first | stack]}, tokens}
  end

  defp eval_drop(%{stack: []}, _tokens) do
    raise Forth.StackUnderflow
  end
  defp eval_drop(%{stack: [_first | rest]} = ev, tokens) do
    {%{ev | stack: rest}, tokens}
  end

  defp eval_swap(%{stack: stack}, _tokens) when length(stack) < 2 do
    raise Forth.StackUnderflow
  end
  defp eval_swap(%{stack: [first, second | rest]} = ev, tokens) do
    {%{ev | stack: [second, first | rest]}, tokens}
  end

  defp eval_over(%{stack: stack}, _tokens) when length(stack) < 2 do
    raise Forth.StackUnderflow
  end
  defp eval_over(%{stack: [first, second | rest]} = ev, tokens) do
    {%{ev | stack: [second, first, second | rest]}, tokens}
  end

  defp eval_push(%{stack: stack} = ev, tokens, token) do
    try do
      String.to_integer(token)
    rescue
      ArgumentError -> raise Forth.UnknownWord, word: token
    end
    {%{ev | stack: [String.to_integer(token) | stack]}, tokens}
  end

  defp eval_def(%{words: words} = ev, tokens) do
    {sequence, rest} = Enum.split_while(tokens, fn(token) -> token != ";" end)

    [word | definition] = sequence

    try do
      _ = String.to_integer(word)
      raise Forth.InvalidWord, word: word
    rescue
      ArgumentError -> :ok
    end

    new_words = Map.put(words, word, definition)
    #IO.puts("Defining \"#{hd(sequence)}\" as \"#{IO.inspect(tl(sequence))}\"")
    {%{ev | words: new_words}, tl(rest)}
  end

  @doc """
  Return the current stack as a string with the element on top of the stack
  being the rightmost element in the string.
  """
  @spec format_stack(evaluator) :: String.t
  def format_stack(%Evaluator{stack: stack}) do
    stack
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defmodule StackUnderflow do
    defexception []
    def message(_), do: "stack underflow"
  end

  defmodule InvalidWord do
    defexception [word: nil]
    def message(e), do: "invalid word: #{inspect e.word}"
  end

  defmodule UnknownWord do
    defexception [word: nil]
    def message(e), do: "unknown word: #{inspect e.word}"
  end

  defmodule DivisionByZero do
    defexception []
    def message(_), do: "division by zero"
  end
end
