defmodule Inky.RpiCommandsTest do
  @moduledoc false

  use ExUnit.Case

  alias Inky.Displays.Display
  alias Inky.RpiCommands
  alias Inky.TestIO

  import Inky.TestUtil, only: [gather_messages: 0, pos2col: 2]
  import Inky.TestVerifier, only: [load_spec: 2, check: 2]

  defp init_pixels(display) do
    for i <- 0..(display.width - 1),
        j <- 0..(display.height - 1),
        do: {{i, j}, pos2col(i, j)},
        into: %{}
  end

  setup_all do
    display = Display.spec_for(:phat)
    pixels = init_pixels(display)

    %{
      display: display,
      pixels: pixels
    }
  end

  describe "happy paths" do
    test "that init dispatches properly", ctx do
      # act
      RpiCommands.init(%{
        display: ctx.display,
        io_args: [],
        io_mod: TestIO
      })

      # assert
      assert_received {:init, []}
    end

    test "that update dispatches properly when the device is never busy", ctx do
      # arrange, read_busy always returns 0
      init_args = %{
        display: ctx.display,
        io_args: [
          read_busy: 0
        ],
        io_mod: TestIO
      }

      state = RpiCommands.init(init_args)

      # act
      :ok = RpiCommands.handle_update(ctx.pixels, :await, state)

      # assert
      assert_received {:init, init_args}
      assert TestIO.assert_expectations() == :ok
      spec = load_spec("data/success1.dat", __DIR__)
      mailbox = gather_messages()
      assert check(spec, mailbox) == {:ok, 31}
    end

    test "that update dispatches properly when the device is a little busy", ctx do
      # arrange, read_busy is a little busy each time, we expect two wait-loops.
      init_args = %{
        display: ctx.display,
        io_args: [
          read_busy: [1, 1, 1, 0, 1, 1, 0]
        ],
        io_mod: TestIO
      }

      state = RpiCommands.init(init_args)

      # act
      :ok = RpiCommands.handle_update(ctx.pixels, :await, state)

      # assert
      assert_received {:init, init_args}
      assert TestIO.assert_expectations() == :ok
      spec = load_spec("data/success2.dat", __DIR__)
      mailbox = gather_messages()
      assert check(spec, mailbox) == {:ok, 41}
    end
  end
end
