import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.hwaseong.tycoon',
  appName: '화성성역: 정조의 24년',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  }
};

export default config;
