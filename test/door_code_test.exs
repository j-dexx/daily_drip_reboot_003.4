defmodule Door do
  use GenStateMachine

  def start_link({code, remaining, unlock_time}) do
    # The GenStateMachine.start_link function takes the module to start and the
    # initial state as an argument.
    GenStateMachine.start_link(Door, {:locked, {code, remaining, unlock_time}})
  end

  def get_state(pid) do
    {state, _data} = :sys.get_state(pid)
    state
  end

  def press(pid, digit) do
    GenStateMachine.cast(pid, {:press, digit})
  end

  ### Server API
  def handle_event(:cast, {:press, digit}, :locked, {code, remaining, unlock_time}) do
    case remaining do
      [digit] ->
        IO.puts "[#{digit}] Correct code. Unlocked for #{unlock_time}"
        {:next_state, :open, {code, code, unlock_time}, unlock_time}
      [digit|rest] ->
        IO.puts "[#{digit}] Correct digit but not yet complete"
        {:next_state, :locked, {code, rest, unlock_time}}
      _ ->
        {:next_state, :locked, {code, code, unlock_time}}
    end
  end

  def handle_event(:cast, {:press, digit}, :open, {code, remaining, unlock_time}) do
    IO.puts "Resetting unlock timer to #{unlock_time}"
    {:next_state, :open, {code, code, unlock_time}, unlock_time}
  end

  def handle_event(:timeout, _, _, data) do
    IO.puts "timeout expired, locking door."
    {:next_state, :locked, data}
  end
end

defmodule DoorCodeTest do
  use ExUnit.Case
  doctest DoorCode

  @code [1, 2, 3]
  @open_time 100

  test "happy path" do
    # We start a door, telling it its code, initializing the remaining digits to
    # be pressed, and how long to remain unlocked.
    {:ok, door} = Door.start_link({@code, @code, @open_time})
    # Verify that it starts out locked
    assert Door.get_state(door) == :locked
    door |> Door.press(1)
    assert Door.get_state(door) == :locked
    door |> Door.press(2)
    assert Door.get_state(door) == :locked
    door |> Door.press(3)
    # Verify that it is unlocked after the correct code is entered
    assert Door.get_state(door) == :open
    :timer.sleep(@open_time)
    # Verify that it is locked again after the specified time
    assert Door.get_state(door) == :locked
  end

  test "button pressed when door is open" do
    {:ok, door} = Door.start_link({@code, @code, @open_time})
    # Verify that it starts out locked
    assert Door.get_state(door) == :locked
    door |> Door.press(1)
    assert Door.get_state(door) == :locked
    door |> Door.press(2)
    assert Door.get_state(door) == :locked
    door |> Door.press(3)
    # Verify that it is unlocked after the correct code is entered
    assert Door.get_state(door) == :open
    door |> Door.press(3)
    # Verify door remain
    assert Door.get_state(door) == :open
    :timer.sleep(@open_time)
    # Verify that it is locked again after the specified time
    assert Door.get_state(door) == :locked
  end

end
