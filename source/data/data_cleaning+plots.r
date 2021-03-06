# Load libraries
library(tidyverse)
library(mclust)
library(chron)
library(lubridate)
library(cluster)
library(fpc)

# Read the data
initialData <- as_tibble(read.csv('./data/shot_logs.CSV', header = TRUE, na.strings = c('NA','','#NA'), stringsAsFactors = FALSE))

# Explore the data a bit
summary(initialData)
head(initialData)
tail(initialData)

# Find NA shot clock data that was NA because the game clock was < 25 seconds left.
# Assumption is that shot clock is equal to game clock in this case. Possible that it just wasn't recorded.
cleanData <- initialData
gameClock <- as.vector(second(fast_strptime(cleanData$GAME_CLOCK, "%M:%S"))) + 
  as.vector(minute(fast_strptime(cleanData$GAME_CLOCK, "%M:%S"))) * 60
shotClock <- is.na(initialData$SHOT_CLOCK)
for(i in 1:length(gameClock)){
  if(shotClock[i] & gameClock[i] < 25){
    cleanData$SHOT_CLOCK[i] <- gameClock[i]
  }
}

# Place NA leftovers in a new dataframe for examination/backup.
weirdShotClock <- subset(cleanData, is.na(SHOT_CLOCK))

# Remove all NA's from cleanData
cleanNoNAData <- subset(cleanData, !is.na(SHOT_CLOCK))

# Custom function to capitalize first letter of each word in a string. 
# Currently not used.
capwords <- function(s, strict = FALSE) {
  cap <- function(s) paste(toupper(substring(s, 1, 1)),
                           {s <- substring(s, 2); if(strict) tolower(s) else s},
                           sep = "", collapse = " " )
  sapply(strsplit(s, split = " "), cap, USE.NAMES = !is.null(names(s)))
}

# Custom function for name format reverse from "firstname lastname" to "lastname, firstname"
nameformatreverse <- function(s) {
  fname <- str_extract(s, "^\\w+")
  lname <- str_extract(s, "\\w+$")
  s <- paste(lname, fname, sep = ", ")
}

# Clean up shooter names to all capitals and "lastname, firstname" format both to ensure uniformity.
shooterName <- cleanNoNAData$player_name
shooterName <- toupper(shooterName)
shooterName <- nameformatreverse(shooterName)

# Clean up defender names to all capitals and no "." both to ensure uniformity.
cleanNoNAData$player_name <- shooterName
cleanNoNAData$CLOSEST_DEFENDER <- toupper(cleanNoNAData$CLOSEST_DEFENDER)
cleanNoNAData$CLOSEST_DEFENDER <- gsub("[.]", "", cleanNoNAData$CLOSEST_DEFENDER)

# Seconds for game clock
cleanNoNASecondsClockData <- cleanNoNAData
cleanNoNASecondsClockData$GAME_CLOCK <- as.vector(second(fast_strptime(cleanNoNAData$GAME_CLOCK, "%M:%S"))) + 
  as.vector(minute(fast_strptime(cleanNoNAData$GAME_CLOCK, "%M:%S"))) * 60

# Remove rows for which touch time doesn't make sense
cleanNoNASecondsClockData <- cleanNoNASecondsClockData[cleanNoNASecondsClockData$TOUCH_TIME > 0, ]

# write.csv(cleanData, "../data/shot_logs_clean.csv")
# write.csv(cleanNoNAData, "../data/shot_logs_clean_noNA.csv")
# write.csv(cleanNoNASecondsClockData, "../data/shot_logs_clean_noNA_secondsclock.csv")


# Plot things.
ggplot(cleanNoNASecondsClockData, aes(SHOT_DIST)) + geom_bar() + 
  labs(title = "Shot Distance Histogram") + xlab("Shot Distance (ft)") + ylab("Total # of shots")
ggplot(cleanNoNASecondsClockData, aes(CLOSE_DEF_DIST)) + geom_bar() + 
  labs(title = "Closest Defender Distance Histogram") + xlab("Closest Defender Distance (ft)") + ylab("Count")
ggplot(cleanNoNASecondsClockData, aes(PERIOD)) + geom_bar() + 
  labs(title = "Period Histogram") + xlab("Period") + ylab("Count")
ggplot(cleanNoNASecondsClockData, aes(GAME_CLOCK)) + geom_bar() + 
  labs(title = "Game Clock Histogram") + xlab("Game Clock (seconds)") + ylab("Count")
ggplot(cleanNoNASecondsClockData, aes(SHOT_CLOCK)) + geom_bar() + 
  labs(title = "Shot Clock Histogram") + xlab("Shot Clock (seconds)") + ylab("Count")
ggplot(cleanNoNASecondsClockData, aes(FINAL_MARGIN)) + geom_bar() + 
  labs(title = "Final Margin Histogram") + xlab("Final Margin") + ylab("Count")
ggplot(cleanNoNASecondsClockData, aes(SHOT_NUMBER)) + geom_bar() + 
  labs(title = "Shot Number Histogram") + xlab("Shot Number") + ylab("Count")
ggplot(cleanNoNASecondsClockData, aes(DRIBBLES)) + geom_bar() + 
  labs(title = "Dribbles Histogram") + xlab("Dribbles") + ylab("Count")
ggplot(cleanNoNASecondsClockData, aes(TOUCH_TIME)) + geom_bar() + 
  labs(title = "Touch Time Histogram") + xlab("Touch Time (seconds)") + ylab("Count")
ggplot(cleanNoNASecondsClockData, aes(PTS_TYPE)) + geom_bar() + 
  labs(title = "Points Type Histogram") + xlab("Point Type") + ylab("Count")
ggplot(cleanNoNASecondsClockData, aes(SHOT_RESULT)) + geom_bar() + 
  labs(title = "Shot Result Histogram") + xlab("Shot Result") + ylab("Count")


# Get the scaled numeric-only data for use for clustering.
kdataunscaled <- cleanNoNASecondsClockData[, c("SHOT_NUMBER", "PERIOD", 
                                               "GAME_CLOCK", "SHOT_CLOCK", "DRIBBLES", 
                                               "TOUCH_TIME", "SHOT_DIST", "CLOSE_DEF_DIST")]
kdata <- scale(kdataunscaled)

# Remove unneeded data for RAM
rm(gameClock)
rm(shooterName)
rm(cleanData)
rm(cleanNoNAData)
rm(initialData)
rm(weirdShotClock)

# Elbow Method for finding the optimal number of clusters
set.seed(123)
# Compute and plot wss for k = 1 to k = 15.
k.max <- 10
wss <- sapply(1:k.max, function(k){kmeans(kdata, k, nstart=50,iter.max = 15 )$tot.withinss})
wss
plot(1:k.max, wss,
     type="b", pch = 19, frame = FALSE,
     xlab="Number of clusters K",
     ylab="Total within-clusters sum of squares")

# Bayesian Inference Criterion for k means to validate choice from Elbow Method
d_clust <- Mclust(as.matrix(kdata), G=1:10,
                  modelNames = mclust.options("emModelNames"))
d_clust$BIC
plot(d_clust)

# Let us apply kmeans for k=2 clusters 
kmm.2 <- kmeans(kdata, 2, nstart = 50, iter.max = 15)
# Let us apply kmeans for k=3 clusters 
kmm.3 <- kmeans(kdata, 3, nstart = 50, iter.max = 15) 
# Let us apply kmeans for k=3 clusters 
kmm.4 <- kmeans(kdata, 4, nstart = 50, iter.max = 15) 
# We keep number of iter.max=15 to ensure the algorithm converges and nstart=50 to
# Ensure that atleat 50 random sets are choosen
kmm.2
kmm.3
kmm.4

# Plot the clusters
clusplot(kdataunscaled, kmm.3$cluster, color=TRUE, shade=TRUE, labels=2, lines=0)

# Centroid Plot against 1st 2 discriminant functions
plotcluster(kdataunscaled, kmm.2$cluster)
plotcluster(kdataunscaled, kmm.3$cluster)
plotcluster(kdataunscaled, kmm.4$cluster)

# Plot kmeans k=2 clusters to see them
cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.2$cluster)) %>%
  ggplot(aes(SHOT_DIST, CLOSE_DEF_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_grid(PERIOD ~ SHOT_RESULT) +
  labs(title = "Shot Distance vs Closest Defender Distance, by Shot Result and Period (2 Clusters)") + 
  xlab("Shot Distance (ft)") + ylab("Closest Defender Distance")

cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.2$cluster)) %>%
  ggplot(aes(DRIBBLES, SHOT_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_grid(PERIOD ~ SHOT_RESULT) +
  labs(title = "Dribbles vs Shot Distance, by Shot Result and Period (2 Clusters)") + 
  ylab("Shot Distance (ft)") + xlab("# of Dribbles")

cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.2$cluster)) %>%
  ggplot(aes(SHOT_DIST, CLOSE_DEF_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_wrap(~ SHOT_RESULT) +
  labs(title = "Shot Distance vs Closest Defender Distance, by Shot Result (2 Clusters)") + 
  xlab("Shot Distance (ft)") + ylab("Closest Defender Distance (ft)")

cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.2$cluster)) %>%
  ggplot(aes(DRIBBLES, SHOT_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_wrap(~ SHOT_RESULT) +
  labs(title = "Dribbles vs Shot Distance, by Shot Result (2 Clusters)") +
  ylab("Shot Distance (ft)") + xlab("# of Dribbles")

# Plot kmeans k=3 clusters to see them
cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.3$cluster)) %>%
  ggplot(aes(SHOT_DIST, CLOSE_DEF_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_grid(PERIOD ~ SHOT_RESULT) +
  labs(title = "Shot Distance vs Closest Defender Distance, by Shot Result and Period (3 Clusters)") + 
  xlab("Shot Distance (ft)") + ylab("Closest Defender Distance")

cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.3$cluster)) %>%
  ggplot(aes(DRIBBLES, SHOT_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_grid(PERIOD ~ SHOT_RESULT) +
  labs(title = "Dribbles vs Shot Distance, by Shot Result and Period (3 Clusters)") + 
  ylab("Shot Distance (ft)") + xlab("# of Dribbles")

cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.3$cluster)) %>%
  ggplot(aes(SHOT_DIST, CLOSE_DEF_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_wrap(~ SHOT_RESULT) +
  labs(title = "Shot Distance vs Closest Defender Distance, by Shot Result (3 Clusters)") + 
  xlab("Shot Distance (ft)") + ylab("Closest Defender Distance (ft)")

cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.3$cluster)) %>%
  ggplot(aes(DRIBBLES, SHOT_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_wrap(~ SHOT_RESULT) +
  labs(title = "Dribbles vs Shot Distance, by Shot Result (3 Clusters)") +
  ylab("Shot Distance (ft)") + xlab("# of Dribbles")

# Plot kmeans k=4 clusters to see them
cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.4$cluster)) %>%
  ggplot(aes(SHOT_DIST, CLOSE_DEF_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_grid(PERIOD ~ SHOT_RESULT) +
  labs(title = "Shot Distance vs Closest Defender Distance, by Shot Result and Period (4 Clusters)") + 
  xlab("Shot Distance (ft)") + ylab("Closest Defender Distance")

cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.4$cluster)) %>%
  ggplot(aes(DRIBBLES, SHOT_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_grid(PERIOD ~ SHOT_RESULT) +
  labs(title = "Dribbles vs Shot Distance, by Shot Result and Period (4 Clusters)") + 
  ylab("Shot Distance (ft)") + xlab("# of Dribbles")

cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.4$cluster)) %>%
  ggplot(aes(SHOT_DIST, CLOSE_DEF_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_wrap(~ SHOT_RESULT) +
  labs(title = "Shot Distance vs Closest Defender Distance, by Shot Result (4 Clusters)") + 
  xlab("Shot Distance (ft)") + ylab("Closest Defender Distance (ft)")

cleanNoNASecondsClockData %>%
  mutate(cluster = factor(kmm.4$cluster)) %>%
  ggplot(aes(DRIBBLES, SHOT_DIST, color = cluster)) +
  geom_point(position = "jitter", alpha = 0.5, size = 0.5) + facet_wrap(~ SHOT_RESULT) +
  labs(title = "Dribbles vs Shot Distance, by Shot Result (4 Clusters)") +
  ylab("Shot Distance (ft)") + xlab("# of Dribbles")

# PCA
pca <- prcomp(kdata)
summary(pca)
biplot(pca, cex = c(0.01,1))

# Get response variable FGM
k_response_variable <- cleanNoNASecondsClockData[, c('FGM')]

#merge pca
pca_matrix <- pca$x
combined_pca_response_variable <- cbind(pca_matrix, k_response_variable)
pca_df <- as.data.frame(combined_pca_response_variable)
write.csv(pca_df, '../data/shot_logs_pca.csv')
# # Hierarchical Agglomerative
# d <- dist(kdata, method = "euclidean") # distance matrix
# fit <- hclust(d, method="ward")
# plot(fit) # display dendogram
# groups <- cutree(fit, k=4) # cut tree into 4 clusters
# # draw dendogram with red borders around the 4 clusters
# rect.hclust(fit, k=4, border="red")

# # Plot the clusters
# clusplot(kdataunscaled, fit$cluster, color=TRUE, shade=TRUE,
#          labels=2, lines=0)
# 
# # Centroid Plot against 1st 2 discriminant functions
# plotcluster(kdataunscaled, fit$cluster)

# # 30 indices to find the best one
# library(NbClust)
# nb <- NbClust(kdata, diss=NULL, distance = "euclidean",
#              min.nc=2, max.nc=4, method = "kmeans",
#              index = "all", alphaBeale = 0.1)
# hist(nb$Best.nc[1,], breaks = max(na.omit(nb$Best.nc[1,])))