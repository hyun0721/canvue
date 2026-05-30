import { defineConfig, type ConfigEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import dts from 'vite-plugin-dts'
import { resolve } from 'path'

export default defineConfig(({ mode }: ConfigEnv) => {
  const isPlayground = mode === 'playground'

  if (isPlayground) {
    return {
      plugins: [vue()],
      root: resolve(__dirname, 'src/playground'),
      resolve: {
        alias: [
          { find: '@', replacement: resolve(__dirname, 'src') },
          { find: 'canvue', replacement: resolve(__dirname, 'src/index.ts') },
        ],
      },
    }
  }

  return {
    plugins: [
      vue(),
      dts({
        include: ['src/**/*.ts', 'src/**/*.vue'],
        exclude: ['src/playground/**'],
        outDir: 'dist',
        insertTypesEntry: true,
      }),
    ],
    build: {
      lib: {
        entry: resolve(__dirname, 'src/index.ts'),
        name: 'Canvue',
        formats: ['es', 'cjs'],
        fileName: (format) => `canvue.${format === 'es' ? 'mjs' : 'cjs'}`,
      },
      rollupOptions: {
        external: ['vue'],
        output: {
          globals: { vue: 'Vue' },
          assetFileNames: 'canvue.[ext]',
        },
      },
      sourcemap: true,
    },
    resolve: {
      alias: [
        { find: '@', replacement: resolve(__dirname, 'src') },
      ],
    },
  }
})
