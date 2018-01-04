defmodule ForthPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  @max_runs 1_000
  @valid_words ["+",  "-", "*", "/", ":"] ++ ~w[dup drop swap over]

  def add_numbers_program_generator do
    gen all numbers <- StreamData.list_of(StreamData.integer(), min_length: 2),
            [first_number | rest] = numbers do
      expected_stack = numbers
                       |> Enum.sum()
                       |> Integer.to_string()
      {expected_stack, "#{first_number} " <> Enum.join(rest, " + ") <> " +"}
    end
  end

  def push_numbers_program_generator do
    gen all numbers <- StreamData.list_of(StreamData.integer()) do
      expected_stack = Enum.join(numbers, " ")
      {expected_stack, Enum.join(numbers, " ")}
    end
  end

  def word_define_program_generator do
    gen all label <- StreamData.string(:alphanumeric, min_length: 1),
            !String.match?(label, ~R/^\d+$/u),
            value <- StreamData.integer() do
      expected_stack = Integer.to_string(value)
      {expected_stack, ": #{label} #{value} ; #{label}"}
    end
  end

  def unknown_word_program_generator do
    gen all word <- StreamData.string(:printable, min_length: 1),
            !String.match?(word, ~R/^\d+$/u),
            !(String.downcase(word) in @valid_words),
            prefix <- StreamData.list_of(StreamData.constant("1 1 + ")),
            suffix <- StreamData.list_of(StreamData.constant(" 1 1 +")),
            expected_message = "unknown word: \"#{word}\"" do
      {expected_message, Enum.join(prefix) <> word <> Enum.join(suffix)}
    end
  end

  property "numbers are pushed onto the stack" do
    check all {expected_stack, program} <- push_numbers_program_generator(),
              max_runs: @max_runs do
      stack = Forth.new
              |> Forth.eval(program)
              |> Forth.format_stack
      assert stack == expected_stack
    end
  end

  property "words may be defined with any alphanumeric characters" do
    check all {expected_stack, program} <- word_define_program_generator(),
              max_runs: @max_runs do
      stack = Forth.new()
                 |> Forth.eval(program)
                 |> Forth.format_stack
      assert stack == expected_stack
    end
  end

  property "numbers may be summed together" do
    check all {expected_stack, program} <- add_numbers_program_generator(),
              max_runs: @max_runs do
      stack = Forth.new()
              |> Forth.eval(program)
              |> Forth.format_stack()
      assert stack == expected_stack
    end
  end

  property "invalid words raise an UnknownWord exception" do
    check all {expected_message, program} <- unknown_word_program_generator(),
              max_runs: @max_runs do
      assert_raise(Forth.UnknownWord, expected_message, fn () ->
        Forth.new()
        |> Forth.eval(program)
      end)
    end
  end
end
