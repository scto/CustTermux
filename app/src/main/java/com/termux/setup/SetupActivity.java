package com.termux.setup;

import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.FragmentPagerAdapter;
import androidx.viewpager.widget.ViewPager;

import com.termux.R;
import com.termux.SkySharedPref;
import com.termux.Utils;

public class SetupActivity extends AppCompatActivity {

    private ViewPager viewPager;
    private Button previousButton;
    private Button nextButton;
    private SetupPagerAdapter pagerAdapter;
    private static final int DELAY_MILLIS = 2000; // 2 seconds delay
    private final Handler setupCompletionHandler = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setTheme(R.style.DarkActivityTheme);
        setContentView(R.layout.activity_setup);

        // Change status bar color
        Window window = getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.setStatusBarColor(Color.BLUE);

        viewPager = findViewById(R.id.viewPager);
        previousButton = findViewById(R.id.previous_button);
        nextButton = findViewById(R.id.next_button);

        pagerAdapter = new SetupPagerAdapter(getSupportFragmentManager(), FragmentPagerAdapter.BEHAVIOR_RESUME_ONLY_CURRENT_FRAGMENT);
        viewPager.setAdapter(pagerAdapter);

        viewPager.addOnPageChangeListener(new ViewPager.OnPageChangeListener() {
            @Override
            public void onPageScrolled(int position, float positionOffset, int positionOffsetPixels) {}

            @Override
            public void onPageSelected(int position) {
                updateButtons(position);
            }

            @Override
            public void onPageScrollStateChanged(int state) {}
        });

        previousButton.setOnClickListener(v -> {
            int currentItem = viewPager.getCurrentItem();
            if (currentItem > 0) {
                viewPager.setCurrentItem(currentItem - 1);
            }
        });

        nextButton.setOnClickListener(v -> {
            int currentItem = viewPager.getCurrentItem();
            if (currentItem < pagerAdapter.getCount() - 1) {
                viewPager.setCurrentItem(currentItem + 1);
            } else {
                // Handle completion or final step
                Utils.showCustomToast(SetupActivity.this, "Finished setup");
                SkySharedPref preferenceManager = new SkySharedPref(this);
                preferenceManager.setKey("isServerSetupDone", "Done");

                // Introduce a delay of 2 seconds before starting Termux
                setupCompletionHandler.postDelayed(() -> {
                    Intent intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
                    if (intent != null) {
                        finish();

                        Log.d("SkyLog", "Out Of The App");
                        startActivity(intent);
                        System.exit(0);
                    }
                }, DELAY_MILLIS);
            }
        });

        setupFocusListeners();

        // Set focus to nextButton at start
        viewPager.post(() -> {
            nextButton.requestFocus();
            nextButton.setFocusable(true);
            nextButton.setFocusableInTouchMode(true);
        });
    }


    private void setupFocusListeners() {
        View.OnFocusChangeListener focusChangeListener = new View.OnFocusChangeListener() {
            @Override
            public void onFocusChange(View view, boolean hasFocus) {
                if (hasFocus) {
                    view.setBackgroundColor(Color.YELLOW); // Highlight the focused button
                } else {
                    view.setBackgroundColor(Color.TRANSPARENT); // Reset to default when focus is lost
                }
            }
        };

        previousButton.setOnFocusChangeListener(focusChangeListener);
        nextButton.setOnFocusChangeListener(focusChangeListener);
    }

    private void updateButtons(int position) {
        if (position == 0) {
            nextButton.requestFocus();
            previousButton.setVisibility(View.GONE);
        } else {
            previousButton.setVisibility(View.VISIBLE);
        }

        if (position == pagerAdapter.getCount() - 1) {
            nextButton.setText("Finish");
        } else {
            nextButton.setText("Next");
        }
    }
}
