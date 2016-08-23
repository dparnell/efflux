defmodule Efflux.Worker do
  use GenServer

  defmodule State do
    defstruct options: [], requests: []
  end

  def start(options \\ []) do
    GenServer.start(__MODULE__, options)
  end

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options)
  end

  def stop(pid) do
    GenServer.stop(pid, :shutdown)
  end

  def run(pid, query, options \\ []) do
    GenServer.call(pid, {:run, query, options})
  end

  def handle_call({:run, query, query_options}, {from, _}, state) do
    options = Keyword.merge(state.options, query_options)
    resp = HTTPoison.get! "http://#{options[:host]}:#{options[:port]}/query?q=#{URI.encode(query)}&db=#{options[:database]}&chunked=true&chunk_size=#{options[:chunk_size]}", %{}, stream_to: self

    new_state = %{ state | requests: [{resp.id, from} | state.requests] }
    {:reply, {:ok, resp.id}, new_state}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: "\n"}, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncChunk{id: request_id, chunk: chunk}, state) do
    {_id, pid} = state.requests
    |> Enum.find(fn {id, _pid} -> id == request_id end)

    case Poison.decode! chunk do
      %{"results" => [%{"series" => [series]}]} ->
        # notify the requesting process that we have a data chunk
        send pid, %Efflux.Data{id: request_id, name: series["name"], columns: series["columns"], points: series["values"]}
      %{"results" => [%{}]} -> 
        # WTF? We got an empty chunk!
        nil
      %{"error" => message} ->
        # we got an error from influx, so send that back to the calling process
        send pid, %Efflux.Error{id: request_id, message: message}
    end

    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncEnd{id: request_id}, state) do
    requests = state.requests
    |> Enum.filter(fn {id, pid} ->
      cond do
        id == request_id ->
          # notify the process that initiated this request that there is no more data
          send pid, %Efflux.EndOfData{id: id}
          # remove this request from the active list
          false
        true -> true
      end
    end)

    new_state = %{ state | requests: requests }
    {:noreply, new_state}
  end

  def handle_info(_value, state) do
    # IO.inspect value
    {:noreply, state}
  end

  @default_options host: "localhost", port: 8086, chunk_size: 10000
  def init(args) do
    {:ok, %State{options: Keyword.merge(@default_options, args)}}
  end

end
