import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "node:path";
export default defineConfig({
    plugins: [react()],
    resolve: {
        extensions: [".js", ".jsx", ".ts", ".tsx", ".json"],
        alias: {
            "@": path.resolve(__dirname, "./src"),
        },
    },
    build: {
        target: "esnext",
        outDir: "build",
        rollupOptions: {
            input: {
                main: path.resolve(__dirname, "index.html"),
                ru: path.resolve(__dirname, "ru/index.html"),
            },
        },
    },
    server: {
        port: 3000,
        open: true,
    },
});
