//
//  BottomSheetPresentationController.swift
//  BottomSheet
//
//  Copyright © 2021 @mtzaquia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the &quot;Software&quot;), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED &quot;AS IS&quot;, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import SwiftUI

private let grabberSize = CGSize(width: 36, height: 5)

final class BottomSheetPresentationController: UIPresentationController {
    private lazy var dimmingView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.black.withAlphaComponent(0.24)
        v.alpha = 0
        return v
    }()

    private lazy var grabberView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = false
        v.alpha = 0
        v.backgroundColor = UIColor.tertiaryLabel
        v.layer.cornerRadius = grabberSize.height / 2
        return v
    }()

    private let maximumHeightRatio: CGFloat = 0.8

    /// The maximum width of the sheet. When the container is wider, the sheet is centered horizontally.
    /// `nil` makes the sheet span the full width of the container.
    public var maximumWidth: CGFloat? {
        didSet {
            containerView?.setNeedsLayout()
        }
    }

    public var cornerRadius: CGFloat = 25 {
        didSet {
            presentedView?.layer.cornerRadius = cornerRadius
        }
    }

    public var prefersGrabberVisible: Bool = false {
        didSet {
            grabberView.isHidden = !prefersGrabberVisible

            presentedViewController.additionalSafeAreaInsets = UIEdgeInsets(
                top: (prefersGrabberVisible ? grabberSize.height : 0) * 3,
                left: 0,
                bottom: 0,
                right: 0
            )
        }
    }

    public var allowsInteractiveDismiss: Bool = true {
        didSet {
            dismissDragGestureRecognizer.isEnabled = allowsInteractiveDismiss
            dismissTapGestureRecognizer.isEnabled = allowsInteractiveDismiss
        }
    }

    private let dismissTapGestureRecognizer = UITapGestureRecognizer()
    let dismissDragGestureRecognizer = UIPanGestureRecognizer()


    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()

        guard let containerView = containerView,
              let presentedView = presentedView else {
            return
        }

        presentedView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        presentedView.layer.masksToBounds = true

        containerView.addSubview(dimmingView)
        presentedView.addSubview(grabberView)

        containerView.addGestureRecognizer(dismissDragGestureRecognizer)
        dimmingView.addGestureRecognizer(dismissTapGestureRecognizer)

        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            grabberView.topAnchor.constraint(equalTo: presentedView.topAnchor, constant: grabberSize.height),
            grabberView.centerXAnchor.constraint(equalTo: presentedView.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: grabberSize.width),
            grabberView.heightAnchor.constraint(equalToConstant: grabberSize.height),
        ])

        dismissTapGestureRecognizer.addTarget(self, action: #selector(handleOverlayTap))
        dismissDragGestureRecognizer.addTarget(self, action: #selector(handlePan))
        dismissDragGestureRecognizer.delegate = self

        (cornerRadius = cornerRadius)
        (prefersGrabberVisible = prefersGrabberVisible)

        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            presentedView.bringSubviewToFront(grabberView)
            transitionCoordinator.animate(
                alongsideTransition: { _ in
                    self.setDecorations(hidden: false)
                }
            )
        } else {
            self.setDecorations(hidden: false)
        }
    }

    @objc private func handleOverlayTap(_ sender: UITapGestureRecognizer) {
        guard let shouldDismissSheetMethod = delegate?.presentationControllerShouldDismiss else {
            presentingViewController.dismiss(animated: true)
            return
        }

        if shouldDismissSheetMethod(self) {
            presentingViewController.dismiss(animated: true)
        }
    }

    @objc private func handlePan(_ sender: UIPanGestureRecognizer) {
        guard sender.state == .began else {
            return
        }

        guard let shouldDismissSheetMethod = delegate?.presentationControllerShouldDismiss else {
            presentingViewController.dismiss(animated: true)
            return
        }

        if shouldDismissSheetMethod(self) {
            presentingViewController.dismiss(animated: true)
        }
    }

    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()

        delegate?.presentationControllerWillDismiss?(self)

        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { _ in
                self.setDecorations(hidden: true)
            })
        } else {
            setDecorations(hidden: true)
        }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)

        if completed {
            delegate?.presentationControllerDidDismiss?(self)
        } else {
            presentedView?.frame = .zero
            containerViewWillLayoutSubviews()
        }
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView,
              let presentedView = presentedView else
        {
            return .zero
        }
        
        let width = min(containerView.bounds.width, maximumWidth ?? .greatestFiniteMagnitude)

        let targetSize = CGSize(
            width: width,
            height: containerView.frame.height
        )

        let sizeThatFits = presentedView.sizeThatFits(targetSize)

        let height = min(sizeThatFits.height, containerView.frame.height * maximumHeightRatio)

        return CGRect(
            x: (containerView.bounds.width - width) / 2,
            y: containerView.bounds.height - height,
            width: width,
            height: height
        )
    }

    private func setDecorations(hidden: Bool) {
        dimmingView.alpha = hidden ? 0 : 1
        grabberView.alpha = hidden || !prefersGrabberVisible ? 0 : 1
    }
}

// MARK: - Scroll hand-off

extension BottomSheetPresentationController: UIGestureRecognizerDelegate {
    /// Inside vertically scrollable content, the drag only starts dismissing when it moves down while the
    /// content is scrolled to the top. Every other drag is left to the scroll view.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissDragGestureRecognizer,
              let scrollView = verticallyScrollableScrollView(at: gestureRecognizer) else {
            return true
        }

        let velocity = dismissDragGestureRecognizer.velocity(in: containerView)
        let isDraggingDown = velocity.y > 0 && velocity.y > abs(velocity.x)
        return isDraggingDown && scrollView.isScrolledToTop
    }

    /// Scroll views inside the sheet wait for the dismiss drag to fail, so that a drag that starts
    /// dismissing does not also scroll the content.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === dismissDragGestureRecognizer,
              let scrollView = otherGestureRecognizer.view as? UIScrollView,
              otherGestureRecognizer === scrollView.panGestureRecognizer,
              let presentedView = presentedView else {
            return false
        }

        return scrollView.isDescendant(of: presentedView) && scrollView.canScrollVertically
    }

    private func verticallyScrollableScrollView(at gestureRecognizer: UIGestureRecognizer) -> UIScrollView? {
        guard let presentedView = presentedView else { return nil }

        let location = gestureRecognizer.location(in: presentedView)
        var view = presentedView.hitTest(location, with: nil)
        while let current = view, current !== presentedView {
            if let scrollView = current as? UIScrollView, scrollView.canScrollVertically {
                return scrollView
            }
            view = current.superview
        }
        return nil
    }
}

private extension UIScrollView {
    var canScrollVertically: Bool {
        isScrollEnabled && contentSize.height + adjustedContentInset.top + adjustedContentInset.bottom > bounds.height
    }

    var isScrolledToTop: Bool {
        contentOffset.y <= -adjustedContentInset.top
    }
}
