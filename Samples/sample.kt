package demo.quicklook

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

data class JobStatus(
    val id: String,
    val owner: String,
    val attempts: Int,
    val healthy: Boolean,
)

fun main() = runBlocking {
    val jobs = listOf(
        JobStatus("api-sync", "platform", 1, true),
        JobStatus("invoice-export", "billing", 3, false),
        JobStatus("cleanup", "ops", 0, true),
    )

    jobs.forEach { job ->
        delay(25)
        println("${job.id}: owner=${job.owner}, attempts=${job.attempts}, healthy=${job.healthy}")
    }
}
