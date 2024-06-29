from collections import defaultdict

import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.cluster import KMeans
import matplotlib.pyplot as plt

# errors_as_list is a list of strings
from log_errors import errors_as_list


class LogCluster:
    def __init__(self, log_file_path):
        self.log_file_path = log_file_path
        self.df = pd.DataFrame()
        self.clusters_range = 14

    def read_log_file(self):
        self.df = pd.DataFrame({'error': errors_as_list})

    def vectorize_errors(self):
        vectorizer = TfidfVectorizer(stop_words='english')
        X = vectorizer.fit_transform(self.df['error'])
        return X

    def plot_elbow_method(self, K, distortions):
        plt.figure(figsize=(10, 6))
        plt.plot(K, distortions, marker='o')
        plt.title('Elbow Method for Optimal k')
        plt.xlabel('Number of Clusters (k)')
        plt.ylabel('Distortion')
        plt.show()

    def perform_clustering(self, X, optimal_k):
        kmeans = KMeans(n_clusters=optimal_k, random_state=42)
        self.df['cluster'] = kmeans.fit_predict(X)

    def print_clusters(self, optimal_k):
        for cluster_id in range(optimal_k):
            cluster_errors = self.df[self.df['cluster'] == cluster_id]['error'].values
            print(f'Cluster {cluster_id + 1} Errors:')

            identical_errors = defaultdict(int)
            for error in cluster_errors:
                identical_errors[error] += 1

            for error in identical_errors:
                print(f'{identical_errors[error]} - {error.strip()}')
            print('\n')

    def cluster_logs(self):
        self.read_log_file()
        X = self.vectorize_errors()

        distortions = self.calculate_distortions(X)

        optimal_k = self.find_optimal_k(distortions)

        self.perform_clustering(X, optimal_k)

        self.print_clusters(optimal_k)

    def calculate_distortions(self, X):
        distortions = []
        K = range(1, self.clusters_range)
        for k in K:
            kmeans = KMeans(n_clusters=k, random_state=42)
            kmeans.fit(X)
            distortions.append(kmeans.inertia_)
        return distortions

    def find_optimal_k(self, distortions):
        self.plot_elbow_method(range(1, self.clusters_range), distortions)

        # Choose the optimal number of clusters (k) based on user input
        optimal_k = int(input("Enter the optimal number of clusters (k): "))
        return optimal_k


if __name__ == "__main__":
    log_clusterer = LogCluster('error_log.txt')
    log_clusterer.cluster_logs()
