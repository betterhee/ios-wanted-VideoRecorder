//
//  RecodeListViewController.swift
//  VideoRecorder
//
//  Created by 신동원 on 2022/10/11.
//

import UIKit
import Photos
import AVKit

final class RecodeListViewController: UIViewController {

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.register(RecodeListCell.self, forCellReuseIdentifier: RecodeListCell.reuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    private lazy var recordingButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "video.badge.plus.fill"),
            style: .plain,
            target: self,
            action: #selector(recordButtonClicked)
        )
        button.tintColor = .systemPurple
        return button
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()
        return indicator
    }()
    
    private let playerViewController: AVPlayerViewController = {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer()
        controller.videoGravity = .resizeAspectFill
        controller.allowsPictureInPicturePlayback = false
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }()
    
//    private lazy var playerViewController: AVPlayerViewController = {
//        let controller = AVPlayerViewController()
//        controller.player = AVPlayer()
//        controller.videoGravity = .resizeAspectFill
//        controller.allowsPictureInPicturePlayback = false
//        controller.updatesNowPlayingInfoCenter = false
//        return controller
//    }()

    private let imageManager = PHCachingImageManager()
    private let fetchSize = 6

    private var fetchLimit = 0
    private var fetchResult: PHFetchResult<PHAsset>!
    private var isFetching: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigation()
        setupViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("1번뷰 register")
        PHPhotoLibrary.shared().register(self)
        fetchMoreAssets()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("1번뷰 appear")
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = tableView.contentOffset.y
        let contentHeight = tableView.contentSize.height
        let height = tableView.bounds.size.height

        if offsetY > contentHeight - height {
            fetchMoreAssets()
        }
    }

    private func setupNavigation() {
        navigationItem.title = "Video List"
        navigationItem.rightBarButtonItem = recordingButton
        navigationItem.backButtonDisplayMode = .minimal
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    private func setupViews() {
        view.addSubview(tableView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func fetchMoreAssets() {
        if !isFetching {
            isFetching = true
            fetchLimit += fetchSize
            activityIndicator.startAnimating()

            fetchAssets(limitedBy: fetchLimit) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.activityIndicator.stopAnimating()
                    self.tableView.reloadData()
                    self.isFetching = false
                }
            }
        }
    }

    private func fetchAssets(limitedBy limit: Int, completion: (() -> Void)?) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.fetchLimit = limit
        fetchResult = PHAsset.fetchAssets(with: .video, options: options)
        completion?()
    }

    @objc
    private func recordButtonClicked() {
        // TODO: 영상녹화화면으로 이동
        let vc = RecordingViewController()
        guard navigationController?.topViewController == self else { return }
        self.navigationController?.pushViewController(vc, animated: true)
//        vc.modalPresentationStyle = .overFullScreen
//        self.present(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension RecodeListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fetchResult.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: RecodeListCell.reuseIdentifier, for: indexPath) as? RecodeListCell else {
            return UITableViewCell()
        }
        let asset = fetchResult.object(at: indexPath.row)
        cell.configure(with: asset)
        imageManager.requestImage(for: asset, targetSize: .zero, contentMode: .aspectFill, options: nil) { image, _ in
            if cell.representedAssetIdentifier == asset.localIdentifier {
                cell.thumbnailImageView.image = image
            }
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension RecodeListViewController: UITableViewDelegate {
    
    func setupPlayer(_ asset: PHAsset, completion: @escaping (AVAsset)->() ) {
        
        
        PHCachingImageManager().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
            guard let avAsset = avAsset else { return }
            let playerItem = AVPlayerItem(asset: avAsset)
            self.playerViewController.player?.replaceCurrentItem(with: playerItem)
            completion(avAsset)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        let asset = fetchResult.object(at: indexPath.row)
        setupPlayer(asset) { asset in
            DispatchQueue.main.async {
                guard self.navigationController?.topViewController == self else { return }
                let vc = VideoPlayerViewController(asset: asset)
                self.navigationController?.pushViewController(vc, animated: false)
            }
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let asset = fetchResult.object(at: indexPath.row)

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, _ in
            // TODO: 백업된 영상도 삭제합니다.
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }) { success, error in
                if success {
                    print("Remove the asset: \(String(describing: asset.localIdentifier))")
                } else {
                    print("Can't remove the asset: \(String(describing: error))")
                }
            }
        }
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        return configuration
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let asset = fetchResult.object(at: indexPath.row)
        var configuration: UIContextMenuConfiguration!
        let assetIdentifier = asset.localIdentifier as NSCopying
            configuration = UIContextMenuConfiguration(
            identifier: assetIdentifier,
            previewProvider: { self.playerViewController },
            actionProvider: nil
        )
        return configuration
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension RecodeListViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.sync {
            guard let details = changeInstance.changeDetails(for: fetchResult) else { return }

            fetchResult = details.fetchResultAfterChanges
            tableView.reloadData()
        }
    }
}
