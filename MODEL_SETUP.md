# Whisper model setup

The app uses `ggml-small.bin` and the optional Core ML encoder
`ggml-small-encoder.mlmodelc`. These large model files are intentionally not
stored in Git.

Place both files here before running the app:

```text
ResilienceInterview/Resources/Models/
├── ggml-small.bin
└── ggml-small-encoder.mlmodelc/
```

The model files can be obtained from the whisper.cpp model distribution. The
Core ML encoder is the `ggml-small-encoder.mlmodelc.zip` archive. After adding
the files, confirm that they are included in the `ResilienceInterview` target's
Copy Bundle Resources phase.
