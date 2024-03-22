defmodule ScribeWeb.FileUpload do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-submit="save" phx-change="validate">
      <.live_file_input upload={@uploads.audio_files} />
      <button type="submit">Upload</button>
    </form>
    <%= if @transcript != "" do %>
      <.link href="/priv/static/transcript.txt" target="_blank">Download</.link>
    <% end %>

    <%= for file <- @uploads.audio_files.entries do %>
      <article class="upload-entry">
        <progress value={file.progress} max="100"><%= file.progress %>%</progress>

        <button type="button" phx-click="cancel-upload" phx-value-ref={file.ref} aria-label="cancel">
          &times;
        </button>

        <%= for err <- upload_errors(@uploads.audio_files, file) do %>
          <p class="alert alert-danger"><%= error_to_string(err) %></p>
        <% end %>
      </article>
    <% end %>

    <%= for err <- upload_errors(@uploads.audio_files) do %>
      <p class="alert alert-danger"><%= error_to_string(err) %></p>
    <% end %>

    <%= for sentence <- String.split(@transcript, ".", trim: true) do %>
      <p><%= sentence %>.</p>
    <% end %>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> assign(
       :transcript,
       "This is a test. There is a lot of text that could be displayed here and it should all dbe displayed in a paragraph. One more."
     )
     |> allow_upload(:audio_files, accept: ~w(audio/*), max_entries: 1)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :audio_files, fn %{path: path}, _entry ->
        dest = Path.join("/Users/alecswanson/code/scribe/data/uploads", Path.basename(path))
        File.cp!(path, dest)

        {:ok, dest}
      end)

    {:noreply,
     socket
     |> update(:uploaded_files, &(&1 ++ uploaded_files))
     |> start_async(:transcribe_file, fn -> transcribe_file(Enum.at(uploaded_files, 0)) end)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_async(:transcribe_file, {:ok, text}, socket) do
    {:noreply, assign(socket, :transcript, text)}
  end

  defp error_to_string(:too_large), do: "Too Large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"

  defp transcribe_file(path) do
    out = Scribe.Model.predict(path)
    File.rm!(path)

    transcript =
      out.chunks
      |> Enum.map(fn x -> x.text end)
      |> Enum.join("")
      |> String.split(".")
      |> Enum.join(".\n")

    priv_dir = :code.priv_dir(:scribe)
    transcript_path = Path.join(priv_dir, Path.join("static", "transcript.txt"))
    IO.inspect(transcript_path)
    File.write!(transcript_path, transcript)

    transcript
  end
end
