defmodule Efflux do
  use Application

  defmodule Data do
    defstruct id: nil, name: nil, columns: nil, points: nil
  end

  defmodule EndOfData do
    defstruct id: nil
  end

  defmodule Error do
    defstruct id: nil, message: nil
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Efflux.Worker.start_link(arg1, arg2, arg3)
      # worker(Efflux.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Efflux.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def connect(options \\ []) do
    Efflux.Worker.start(Keyword.merge(Application.get_env(:efflux, :config, []), options))
  end

  def run(pid, query, options \\ []) do
    Efflux.Worker.run(pid, query, options)
  end

  def query(query, options) do
    reduce(query, [], fn x, acc -> [x | acc] end, options)
  end

  def reduce(query, acc, row_fn, options \\ []) do
    {:ok, pid} = connect(options)
    run(pid, query, options)
    _reduce_loop(acc, row_fn)
  end

  defp _reduce_loop(acc, row_fn) do
    receive do
      %Efflux.Data{points: points} ->
        # We have a batch of points, reduce them
        new_acc = Enum.reduce points, acc, row_fn
        _reduce_loop(new_acc, row_fn)
      %Efflux.EndOfData{} -> {:ok, acc}
      %Efflux.Error{message: message} -> {:error, message}
    after
      60_000 -> {:error, "Receive timeout"}
    end
  end

end
