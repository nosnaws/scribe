defmodule Scribe.Model do
  @model_name "openai/whisper-tiny"

  def serving() do
    IO.puts("Loading model...")
    Nx.default_backend(EXLA.Backend)
    {:ok, whisper} = Bumblebee.load_model({:hf, @model_name})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, @model_name})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, @model_name})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, @model_name})

    IO.puts("Model initialized")

    Bumblebee.Audio.speech_to_text_whisper(whisper, featurizer, tokenizer, generation_config,
      defn_options: [compiler: EXLA],
      timestamps: :segments,
      chunk_num_seconds: 30
    )
  end

  def predict(audio_file_path) do
    IO.puts("Running on #{audio_file_path}")
    Nx.Serving.batched_run(ScribeModel, {:file, audio_file_path})
  end
end
