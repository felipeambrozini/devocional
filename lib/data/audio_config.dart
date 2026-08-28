// Base dos áudios pré-gerados. Compartilhado entre Voz (que toca) e
// AudioOffline (que baixa). Um só String.fromEnvironment para não duplicar.
const audioBaseUrl = String.fromEnvironment('AUDIO_BASE_URL', defaultValue: '');
