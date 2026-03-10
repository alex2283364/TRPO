
import { defineConfig } from 'prisma/config'
import { config } from 'dotenv'
import { resolve } from 'path'

config({ path: resolve(__dirname, '.env') })

export default defineConfig({
  datasource: {
    provider: 'postgresql',
    url: process.env.DATABASE_URL,
    directUrl: process.env.DATABASE_URL,
  },
})
